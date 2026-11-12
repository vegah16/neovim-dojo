-- What an open task costs per editor event: deferred checks are shared, an
-- idle tick schedules nothing, and a buffer's path is resolved once.
local dojo = require("neovim_dojo")
dojo.setup()
local session = dojo.session
session.clear_progress(true)
local uv = vim.uv or vim.loop

local scheduled, resolved, checks = 0, 0, 0
local schedule, realpath, check = vim.schedule, uv.fs_realpath, session.check
vim.schedule = function(...)
  scheduled = scheduled + 1
  return schedule(...)
end
uv.fs_realpath = function(...)
  resolved = resolved + 1
  return realpath(...)
end
session.check = function(...)
  checks = checks + 1
  return check(...)
end
local function fire(event, times)
  for _ = 1, times or 1 do
    vim.api.nvim_exec_autocmds(event, {})
  end
end
local function settle()
  vim.wait(20, function()
    return false
  end, 5)
end
local function reset()
  settle()
  scheduled, resolved, checks = 0, 0, 0
end
local function completed(id)
  return session.lesson_state(session.find_lesson(id)).completed
end

-- A burst of events shares one deferred check.
assert(session.start("counted-word-ends"))
reset()
fire("CursorMoved", 25)
assert(scheduled == 1 and checks == 0, ("25 events defer one check, not %d"):format(scheduled))
settle()
assert(checks == 1, "the deferred check runs once")
fire("CursorMoved")
settle()
assert(scheduled == 2 and checks == 2, "a later event defers a new check")

-- SafeState checks at once and schedules nothing. A callback scheduled from
-- SafeState would wake the editor into the next SafeState, without end.
reset()
fire("SafeState", 25)
assert(scheduled == 0, ("an idle tick must not schedule anything, got %d"):format(scheduled))
assert(checks == 25, "an idle tick checks at once")
fire("CursorMoved")
fire("SafeState")
settle()
assert(scheduled == 1 and checks == 26, "the deferred check is dropped when an idle tick ran it first")
assert(not completed("counted-word-ends"))
vim.api.nvim_win_set_cursor(0, { 1, 16 }) -- the end of the third word, no event
fire("SafeState")
assert(completed("counted-word-ends"), "an outcome reached without another event passes at the next idle tick")
session.quit()

-- A file-backed task resolves each buffer's path once, not on every event.
assert(session.start("two-views-one-file"))
local primary = vim.api.nvim_get_current_buf()
local root = vim.fs.dirname(vim.api.nvim_buf_get_name(primary))
assert(session.owns_path(root), "the task has a fixture root")
vim.fn.writefile({ "support" }, root .. "/support.txt")
vim.cmd.edit(vim.fn.fnameescape(root .. "/support.txt"))
local support = vim.api.nvim_get_current_buf()
fire("CursorMoved")
assert(vim.fn.maparg(",r", "n", false, true).buffer == 1, "a fixture file gets the task controls")
reset()
fire("CursorMoved", 20)
fire("SafeState", 20)
settle()
assert(resolved == 0, ("a known fixture file is not resolved again, got %d"):format(resolved))

local outside = vim.fn.tempname() .. "-outside.txt"
vim.fn.writefile({ "outside" }, outside)
vim.cmd.edit(vim.fn.fnameescape(outside))
fire("CursorMoved")
assert(vim.fn.maparg(",r", "n") == "", "a file outside the fixture gets no task controls")
reset()
fire("CursorMoved", 20)
fire("SafeState", 20)
settle()
assert(resolved == 0, ("a known outside file is not resolved again, got %d"):format(resolved))

-- A renamed buffer is resolved again, and a missing file is never remembered.
vim.api.nvim_buf_set_name(support, root .. "/renamed.txt")
vim.api.nvim_set_current_buf(support)
reset()
fire("CursorMoved", 5)
assert(resolved == 5, "a file that does not exist yet is resolved every time")
vim.cmd("silent write!")
reset()
fire("CursorMoved", 5)
assert(resolved == 1, ("a renamed buffer is resolved once more, got %d"):format(resolved))
vim.cmd.enew()
fire("CursorMoved")
assert(vim.fn.maparg(",r", "n") == "", "an unnamed buffer is not a fixture file")

vim.schedule, uv.fs_realpath, session.check = schedule, realpath, check
session.quit()
vim.fn.delete(outside)
session.clear_progress(true)
print("DOJO EVENT COST OK")
