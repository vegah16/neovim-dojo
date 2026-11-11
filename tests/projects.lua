-- File-backed tasks: every native project outcome, reset, cleanup, and the
-- extension hooks a configuration uses for its own plugins.
require("neovim_dojo").setup()
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local workspace = require("neovim_dojo.workspace")
local original_setup = dojo.options.setups.project
local original_scenarios = dojo.options.drills and dojo.options.drills.scenarios
local context, runtime
local roots = {}
dojo.options.setups.project = function(c, s)
  context = c
  original_setup(c, s)
end
dojo.options.drills = dojo.options.drills or {}
dojo.options.drills.scenarios = {
  new = function(c, s, cb)
    context = c
    runtime = require("neovim_dojo.drills.scenarios").new(c, s, cb)
    return runtime
  end,
}
local function files(check)
  for relative, lines in pairs(check.files or {}) do
    local path = workspace.path(context, relative)
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      if check.disk then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent noautocmd write")
        end)
      end
    else
      workspace.write(context, relative, lines)
    end
  end
  for _, relative in ipairs(check.absent or {}) do
    vim.fn.delete(workspace.path(context, relative), "rf")
  end
  for _, relative in ipairs(check.dirs or {}) do
    vim.fn.mkdir(workspace.path(context, relative), "p")
  end
end
local function reach(check)
  files(check)
  if check.layout then
    vim.api.nvim_set_current_tabpage(context.tab)
    vim.api.nvim_win_set_buf(0, context.buf)
    vim.cmd("only!")
    for _ = 2, check.layout.count do
      vim.cmd.vsplit()
    end
    if context.lesson.id == "exchange-split-positions" then
      workspace.edit(context, "alpha.txt")
      vim.cmd("wincmd H")
    end
  end
  for _, relative in ipairs(check.visited or {}) do
    workspace.edit(context, relative)
  end
  if check.tcd then
    vim.cmd.tcd(vim.fn.fnameescape(workspace.path(context, check.tcd)))
  end
  if check.position then
    workspace.edit(context, check.position.file)
    if check.position.cursor then
      vim.api.nvim_win_set_cursor(0, check.position.cursor)
    end
  elseif not check.layout then
    vim.api.nvim_set_current_tabpage(context.tab)
    vim.api.nvim_win_set_buf(0, context.buf)
  end
end
local task_count, scene_count = 0, 0
local ids = { "project-views" }
for _, topic_id in ipairs(ids) do
  for _, task in ipairs(dojo.find_topic(topic_id).lessons) do
    dojo.start(task.id)
    roots[#roots + 1] = context.project_root
    task_count = task_count + 1
    if task.kind == "lesson" then
      assert(not dojo.check(), task.id .. ": initial state must not pass")
      if task.check.kind ~= "manual" then
        reach(task.check)
        assert(
          workspace.check(context, task.check),
          task.id .. ": completed outcome should pass " .. vim.fn.getcwd() .. " scope " .. vim.fn.haslocaldir()
        )
        dojo.check()
        assert(dojo.lesson_state(task).completed, task.id .. ": session should record completion")
      end
    else
      runtime:start()
      for _ = 1, #task.drill.scenes do
        local scene = runtime.scene
        assert(not runtime:check(), task.id .. ": untouched round must not pass")
        reach(scene.check)
        -- Negative control: a requested file with one unintended extra line.
        local relative = next(scene.check.files or {})
        if relative then
          local wanted = scene.check.files[relative]
          local wrong = vim.list_extend(vim.deepcopy(wanted), { "unintended change" })
          files({ files = { [relative] = wrong } })
          assert(not runtime:check(), task.id .. ": wrong file contents must fail")
          files({ files = { [relative] = wanted } })
        end
        assert(runtime:check(), task.id .. ": correct round should pass")
        scene_count = scene_count + 1
      end
      assert(dojo.lesson_state(task).completed, task.id .. ": all rounds should complete")
      dojo.reset()
      assert(runtime.phase == "ready", task.id .. ": reset must return to ready")
    end
    -- New paths created while practising must not survive reset.
    workspace.write(context, "leftover.txt", { "owned" })
    dojo.reset()
    assert(vim.fn.filereadable(workspace.path(context, "leftover.txt")) == 0, "reset must remove added paths")
    dojo.quit()
  end
end
assert(task_count == 6 and scene_count == 5, "every project task and scene must be covered")
assert(
  vim.wait(5000, function()
    for _, root in ipairs(roots) do
      if vim.fn.isdirectory(root) == 1 then
        return false
      end
    end
    return true
  end, 50),
  "all owned projects must retire"
)
print("DOJO PROJECT CONTRACTS OK: 6 tasks, " .. scene_count .. " scenes; positive, negative, reset and cleanup")
-- The edit alone, or the close alone, must not satisfy the safe-close lesson.
assert(dojo.start("modified-buffer-safe-close"))
assert(#vim.api.nvim_tabpage_list_wins(context.tab) == 2, "the safe-close lesson should start with two views")
vim.api.nvim_buf_set_lines(context.buf, 0, -1, false, { "notes retained" })
assert(not dojo.check(), "an edit that is still shown in two views must not pass")
vim.cmd.close()
dojo.check()
assert(
  dojo.lesson_state(dojo.find_lesson("modified-buffer-safe-close")).completed,
  "closing one view should keep the edit"
)
assert(vim.bo[context.buf].modified, "the retained edit should still be unsaved")
dojo.quit()
assert(dojo.start("retrieve-working-set-drill"))
runtime:start()
workspace.edit(context, "alpha.txt")
assert(vim.fn.maparg(",k", "n", false, true).buffer == 1, "project file buffers need the drill check mapping")
dojo.hint()
local help = vim.api.nvim_get_current_buf()
assert(help ~= context.buf and not vim.bo[help].modifiable, "auxiliary hints should be scrollable read-only help")
assert(
  table.concat(vim.api.nvim_buf_get_lines(help, 0, -1, false), "\n"):find("GOAL", 1, true),
  "auxiliary help should contain the actual instructions"
)
vim.fn.maparg("q", "n", false, true).callback()
assert(not vim.api.nvim_buf_is_valid(help), "q should retire the owned help buffer")
dojo.quit()
local original_requirements = dojo.options.requirements
assert(dojo.start("create-vertical-split"))
local retained = vim.api.nvim_get_current_buf()
dojo.options.requirements = function()
  return false, { "capability:deliberately-missing" }
end
assert(not dojo.start("two-views-one-file"), "direct starts must respect missing requirements")
assert(vim.api.nvim_get_current_buf() == retained, "unavailable starts must preserve the active fixture")
dojo.options.requirements = original_requirements
dojo.quit()
print("DOJO PROJECT RECOVERY AND REQUIREMENTS OK")

-- A configuration adds plugin-specific fixture handling through extend().
local calls = { cleanup = 0, observe = 0, model = 0 }
workspace.extend({ name = "probe", cleanup = error })
workspace.extend({
  name = "probe", -- the same name replaces the first registration
  cleanup = function(c)
    assert(c.workspace, "extension cleanup runs while the fixture still exists")
    calls.cleanup = calls.cleanup + 1
  end,
  observe = function(c)
    calls.observe = calls.observe + 1
    c.workspace.seen.probe = true
  end,
  check = function(c, check)
    if check.probe and not c.workspace.probe_done then
      return false
    end
  end,
  models = {
    probe = function(c)
      calls.model = calls.model + 1
      c.workspace.model_ready = true
    end,
  },
})
require("neovim_dojo").register({
  id = "extension-probe",
  topics = {
    {
      id = "extension-probe",
      title = "Probe",
      lessons = {
        workspace.lesson(
          "extension-probe",
          "Probe",
          "Reach the extension outcome.",
          { "Nothing to type." },
          { "probe" },
          { probe = true },
          { model = "probe", git = vim.fn.executable("git") == 1 }
        ),
      },
    },
  },
})
if vim.fn.executable("git") == 1 then
  assert(
    vim.tbl_contains(dojo.find_lesson("extension-probe").requires.capabilities, "git"),
    "a Git fixture requires git"
  )
end
assert(dojo.start("extension-probe"))
assert(calls.model == 1 and context.workspace.model_ready, "a scene model should reach its extension")
assert(
  require("neovim_dojo.session").owns_path(workspace.path(context, "main.txt")),
  "the session owns its fixture paths"
)
assert(not require("neovim_dojo.session").owns_path(vim.fn.getcwd(-1, -1) .. "/elsewhere"), "and nothing outside them")
if vim.fn.executable("git") == 1 then
  assert(workspace.git(context, "log", "--format=%s"):find("Fixture baseline", 1, true), "a Git fixture has a baseline")
end
vim.cmd("doautocmd <nomodeline> CursorMoved")
assert(calls.observe > 0 and context.workspace.seen.probe, "session events should reach the extension")
assert(not dojo.check(), "an extension check may refuse an outcome")
context.workspace.probe_done = true
assert(dojo.check(), "and accept it once its condition holds")
local before = calls.cleanup
dojo.quit()
assert(calls.cleanup > before, "quit should run the extension cleanup")
print("DOJO WORKSPACE EXTENSION OK")

dojo.options.setups.project = original_setup
dojo.options.drills.scenarios = original_scenarios
