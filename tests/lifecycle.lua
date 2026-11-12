-- Path resume, owned buffer fixtures and cursor ownership.
require("neovim_dojo").setup()
local dojo = require("neovim_dojo.session")
local ui = require("neovim_dojo.ui.snacks")
local original_snacks = _G.Snacks
local original_pick = original_snacks and original_snacks.picker.pick
local picker
local function capture_picker(options)
  picker = options
end
if original_snacks then
  original_snacks.picker.pick = capture_picker
else
  _G.Snacks = { picker = { pick = capture_picker } }
end

dojo.clear_progress(true)

-- Path progress and the next entry are derived from task completion.
do
  local path = dojo.find_path("neovim-fundamentals")
  local first, second = dojo.find_lesson(path.entries[1]), dojo.find_lesson(path.entries[2])
  local progress = dojo.path_progress("neovim-fundamentals")
  assert(progress.completed == 0 and progress.total == #path.entries, "a path starts with nothing complete")
  assert(dojo.path_progress("no-such-path") == nil and select(2, dojo.next_path_entry("no-such-path")) == "unknown_path")
  local entry = dojo.next_path_entry(path)
  assert(entry.task == first and entry.position == 1 and entry.available, "resume begins at the first entry")
  assert(dojo.toggle_completion(first))
  assert(dojo.path_progress(path).completed == 1, "progress accepts a path or its ID")
  assert(dojo.next_path_entry(path).task == second, "resume passes completed entries")
  assert(select(2, dojo.next_path_entry(path, "inspect-registers")) == "entry_not_in_path")
  assert(dojo.next_path_entry(path, second.id).position == 3, "the search continues after the given entry")
  assert(select(2, dojo.next_path_entry(path, path.entries[#path.entries])) == "no_incomplete_entry")

  local requirements = dojo.options.requirements
  dojo.options.requirements = function(task)
    return task ~= second, task == second and { "capability:probe" } or {}
  end
  local blocked = dojo.next_path_entry(path)
  assert(
    blocked.task == second and not blocked.available and blocked.missing[1] == "capability:probe",
    "an unavailable entry blocks resume; it is never skipped"
  )
  local started, reason = dojo.start_next_path_entry(path)
  assert(not started and reason == "unavailable" and vim.api.nvim_buf_get_name(0) == "")
  dojo.options.requirements = requirements
  assert(dojo.toggle_completion(first))

  -- Inside a path task, next waits for completion and then moves forward only.
  assert(select(2, dojo.start_next_path_entry()) == "no_active_path")
  local fifth, sixth = dojo.find_lesson(path.entries[5]), path.entries[6]
  assert(dojo.start(fifth.id, path.id))
  assert(vim.fn.maparg(",n", "n") ~= "", "a path task maps the next key")
  started, reason = dojo.start_next_path_entry()
  assert(not started and reason == "current_incomplete", "next does not abandon an incomplete task")
  assert(dojo.toggle_completion(fifth))
  started, entry = dojo.start_next_path_entry()
  assert(
    started and entry.task.id == sixth and vim.api.nvim_buf_get_name(0) == "neovim-dojo://" .. sixth,
    "next opens the following incomplete entry, not an earlier one"
  )
  dojo.quit()
  assert(dojo.start(fifth.id, "no-such-path") and vim.fn.maparg(",n", "n") == "", "an unknown path is ignored")
  dojo.quit()
  dojo.clear_progress(true)
end

ui.set_filter("path", "neovim-fundamentals")
dojo.start("create-vertical-split", "neovim-fundamentals")
dojo.toggle_current_completion()
ui.open(dojo)
picker.actions.dojo_next_path_entry({ close = function() end })
assert(
  vim.wait(1000, function()
    return vim.api.nvim_buf_get_name(0) == "neovim-dojo://hjkl-target-grid"
  end),
  "catalogue resume should revisit the first incomplete task, even with a later task still active"
)
dojo.quit()
ui.reset_filters()
_G.Snacks = original_snacks
if original_snacks then
  original_snacks.picker.pick = original_pick
end

for _, id in ipairs({ "inspect-open-buffers", "switch-hidden-buffer", "switch-alternate-buffer" }) do
  dojo.start(id)
  local owned = {}
  local roots = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find("-neovim-dojo-buffers/", 1, true) then
      owned[#owned + 1] = buf
      roots[vim.fs.dirname(vim.api.nvim_buf_get_name(buf))] = true
    end
  end
  assert(#owned > 0, "the buffer lesson should create support fixtures")
  -- The primary can be hidden after visiting a support buffer.
  local primary = vim.fn.bufnr("neovim-dojo://" .. id)
  vim.api.nvim_buf_delete(primary, { force = true })
  local replacement = vim.api.nvim_get_current_buf()
  assert(
    vim.wait(1000, function()
      for _, buf in ipairs(owned) do
        if vim.api.nvim_buf_is_valid(buf) then
          return false
        end
      end
      return true
    end),
    "external wipe should retire every owned support buffer"
  )
  for root in pairs(roots) do
    assert(vim.fn.isdirectory(root) == 0, "external wipe should remove the owned temporary directory")
  end
  assert(vim.api.nvim_get_current_buf() == replacement, "external wipe cleanup should preserve the replacement view")
  assert(dojo.start(id), "a wiped lesson should reopen without name collisions")
  dojo.quit()
end

dojo.clear_progress(true)
print("DOJO LIFECYCLE OK")

-- Cursor checks must observe the actual task buffer, even with a lookalike split.
require("neovim_dojo").register({
  id = "cursor-ownership-probe",
  topics = {
    {
      id = "cursor-ownership-probe",
      title = "Probe",
      lessons = {
        {
          id = "probe-cursor-target",
          title = "Probe",
          objective = "Reach the actual task buffer",
          steps = { "Use native motions." },
          lines = { "ORIGIN", "TARGET" },
          check = { kind = "cursor_on_text", line = 2, text = "TARGET" },
        },
        {
          id = "probe-cursor-return",
          title = "Probe",
          objective = "Reach the actual task buffer",
          steps = { "Use native motions." },
          lines = { "ORIGIN", "TARGET" },
          check = { kind = "cursor_round_trip", target = { line = 2, text = "TARGET" }, origin = { 1, 0 } },
        },
        {
          id = "probe-edit-return",
          title = "Probe",
          objective = "Reach the actual task buffer",
          steps = { "Use native motions." },
          lines = { "unfinished" },
          check = { kind = "buffer_equals_at_cursor", lines = { "fixed" }, cursor = { 1, 0 } },
        },
      },
    },
  },
})
for _, id in ipairs({ "probe-cursor-target", "probe-cursor-return", "probe-edit-return" }) do
  assert(dojo.start(id))
  local primary = vim.api.nvim_get_current_buf()
  local window = vim.api.nvim_get_current_win()
  if id == "probe-cursor-return" then
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert(not dojo.check())
  end
  if id == "probe-edit-return" then
    vim.api.nvim_buf_set_lines(primary, 0, -1, false, { "fixed" })
  end
  vim.cmd.vsplit()
  local foreign = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, foreign)
  vim.api.nvim_buf_set_lines(foreign, 0, -1, false, { "ORIGIN", "TARGET" })
  vim.api.nvim_win_set_cursor(0, { id == "probe-cursor-target" and 2 or 1, 0 })
  assert(not dojo.check(), id .. ": a lookalike buffer must not satisfy cursor ownership")
  vim.api.nvim_buf_delete(foreign, { force = true })
  vim.api.nvim_set_current_win(window)
  vim.api.nvim_win_set_cursor(0, { id == "probe-cursor-target" and 2 or 1, 0 })
  assert(dojo.check(), id .. ": the actual task destination must still pass")
  dojo.quit()
end
print("DOJO CURSOR OWNERSHIP OK")
