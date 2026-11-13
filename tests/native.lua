-- Every native outcome task, replayed with the keys of tests/solutions.lua:
-- untouched fixtures fail, intermediate steps and wrong results fail, a real
-- solution passes, and scenario drills reject damaged text.
require("neovim_dojo").setup()
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local root = vim.fn.getcwd()
local replay = dofile("tests/replay.lua")
local keys = replay.keys
local solutions = dofile("tests/solutions.lua")
local lesson_count, drill_count = replay.all(solutions)
-- The solutions that need a main loop, typed into a second editor.
do
  local remote = replay.remote(
    { vim.v.progpath, "--headless", "--embed", "--clean", "-u", "tests/init.lua", "-i", "NONE" },
    root .. "/tests/solutions.lua",
    { setup = 'require("neovim_dojo").setup()', cwd = root }
  )
  local ok, lessons, drills = pcall(remote.all, remote)
  remote:close()
  assert(ok, lessons)
  assert(lessons == 3 and drills == 0, "the command-line window lessons are typed into a second editor")
  lesson_count, drill_count = lesson_count + lessons, drill_count + drills
end
-- Every task is replayed above or completed by hand, for a stated reason.
do
  for id, reason in pairs(solutions.manual) do
    local task = assert(dojo.find_lesson(id), "solutions.lua names an unknown task: " .. id)
    assert(task.check.kind == "manual", id .. ": listed as manual but has a check")
    assert(type(reason) == "string" and #reason > 10, id .. ": a manual lesson needs its reason")
  end
  for _, task in ipairs(dojo.lessons()) do
    local replayed = solutions.lessons[task.id] or solutions.drills[task.id] or solutions.runs[task.id]
    assert(replayed or solutions.manual[task.id], task.id .. ": no solution in tests/solutions.lua")
    assert(not (replayed and solutions.manual[task.id]), task.id .. ": listed twice in tests/solutions.lua")
  end
end
dojo.clear_progress(true)
-- A floating window, such as a notification, is not part of a layout.
do
  assert(dojo.start("close-other-windows"))
  local workspace = require("neovim_dojo.workspace")
  local context = { tab = vim.api.nvim_get_current_tabpage() }
  local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 10,
    height = 1,
  })
  assert(#vim.api.nvim_tabpage_list_wins(context.tab) == 3 and #workspace.windows(context) == 2)
  keys("<C-w>o")
  assert(#workspace.windows(context) == 1, "the layout has one window left")
  pcall(vim.api.nvim_win_close, float, true)
  dojo.quit()
  dojo.clear_progress(true)
end
-- Setting a mark leaves the cursor in place; only the round trip may pass.
assert(dojo.start("line-and-exact-marks"))
keys("ma")
assert(not dojo.check(), "setting the mark without leaving and returning must not pass")
keys("G")
assert(not dojo.check(), "reaching the destination is only half of the round trip")
keys("'a")
assert(not dojo.check(), "the linewise mark jump lands on the first nonblank, not the exact column")
keys("`a")
dojo.check()
assert(dojo.lesson_state(dojo.find_lesson("line-and-exact-marks")).completed, "the exact mark round trip should pass")
dojo.quit()
assert(dojo.start("jump-list-change-list"))
assert(not dojo.check(), "history comparison must remain self-assessed")
dojo.quit()
local runner_module = require("neovim_dojo.drills.scenarios")
-- A pool larger than the run is sampled, so later scenes are reachable.
do
  local buf = vim.api.nvim_create_buf(true, true)
  local scenes = {}
  for _, goal in ipairs({ "first", "second", "third" }) do
    scenes[#scenes + 1] = { goal = goal, lines = { goal }, check = { lines = { "done" } } }
  end
  local runtime = runner_module.new({ buf = buf }, { rounds = 2, scenes = scenes }, { status = function() end })
  local seen = {}
  for _ = 1, 40 do
    runtime:reset()
    assert(
      #runtime.schedule == 2 and runtime.schedule[1].goal ~= runtime.schedule[2].goal,
      "a run uses distinct scenes"
    )
    seen[runtime.schedule[1].goal], seen[runtime.schedule[2].goal] = true, true
  end
  assert(seen.first and seen.second and seen.third, "every scene of a larger pool should be reachable")
  vim.api.nvim_buf_delete(buf, { force = true })
end
-- Actual session integration, reset and explicit failed check remain unscored.
dojo.start("operator-repair-drill")
keys("<CR>")
keys(",k")
assert(not dojo.lesson_state(dojo.find_lesson("operator-repair-drill")).completed)
dojo.reset()
dojo.quit()
-- A finished untimed drill shows its result in the panel it returns to.
do
  local id = "repeat-correction-drill"
  local task, commands = dojo.find_lesson(id), solutions.drills[id]
  local previous, runtime = dojo.options.drills, nil
  dojo.options.drills = {
    scenarios = {
      new = function(c, s, cb)
        runtime = runner_module.new(c, s, cb)
        return runtime
      end,
    },
  }
  dojo.start(id)
  local buf = vim.api.nvim_get_current_buf()
  local function panel()
    local namespace = vim.api.nvim_get_namespaces()["neovim-dojo.instructions"]
    local lines = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
      for _, line in ipairs(mark[4].virt_lines or {}) do
        local text = ""
        for _, chunk in ipairs(line) do
          text = text .. chunk[1]
        end
        lines[#lines + 1] = text
      end
    end
    return lines
  end
  assert(not table.concat(panel(), "\n"):find("Last:", 1, true), "no result line before the first run")
  runtime:start()
  for _ = 1, task.drill.rounds do
    for index, original in ipairs(task.drill.scenes) do
      if vim.deep_equal(original, runtime.scene) then
        keys(commands[index])
        break
      end
    end
    assert(runtime:check(), id .. ": a solved round must advance")
  end
  assert(dojo.lesson_state(task).completed, id .. ": the session run must complete the drill")
  assert(
    vim.tbl_contains(panel(), ("│   Last: %d rounds · untimed"):format(task.drill.rounds)),
    "a finished untimed drill should show its rounds under STATUS"
  )
  dojo.quit()
  dojo.options.drills = previous
end
-- Two generated rounds that no built-in task uses; a configuration's pack
-- does. Both were wrong when typed into a real terminal.
do
  local text_actions = require("neovim_dojo.drills.text_actions")
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_set_current_buf(buf)
  local function runner(specification)
    local shown
    local runtime = text_actions.new({ buf = buf }, specification, {
      status = function(status)
        shown = status
      end,
      complete = function() end,
      random = function(first)
        return first
      end,
    })
    runtime:reset()
    runtime:start()
    return runtime, function()
      return shown
    end
  end
  -- A mapping that moves a line goes on after the text has changed. The
  -- round is taken when the editor is idle, or the rest of the mapping runs
  -- on the next board.
  local moving = runner({ variant = "move_visual_line", rounds = 2 })
  local lines, target, anchor = vim.api.nvim_buf_get_lines(buf, 0, -1, false), nil, nil
  for row, line in ipairs(lines) do
    target = line == "MOVE THIS LINE" and row or target
    anchor = line:find("ANCHOR", 1, true) and row or anchor
  end
  local moved = table.remove(lines, target)
  anchor = anchor - (target < anchor and 1 or 0)
  table.insert(lines, lines[anchor]:find("below", 1, true) and anchor + 1 or anchor, moved)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  assert(not moving:on_event({ event = "TextChanged" }), "a line-moving round must wait for the editor to be idle")
  assert(moving.completed == 0 and moving:on_event({ event = "SafeState" }), "and is taken at the idle moment")
  assert(moving.completed == 1 and vim.api.nvim_win_get_cursor(0)[1] == 7, "the next round starts on its target line")
  -- The key that repeats a character motion is the editor's business.
  local _, native_status = runner({ variant = "character_motion", rounds = 12 })
  local motion = native_status():match("use ([fFtT]){char}")
  assert(
    native_status():find(("then repeat %s to reach"):format(motion), 1, true),
    "by default the motion repeats itself"
  )
  local _, status = runner({
    variant = "character_motion",
    rounds = 12,
    repeat_keys = { f = "x", F = "x", t = "x", T = "x" },
  })
  assert(status():find("then repeat x to reach", 1, true), "repeat_keys names another key in the round's status")
  vim.api.nvim_buf_delete(buf, { force = true })
end
print(("DOJO NATIVE OUTCOMES OK: %d lessons and %d drills replayed with real keys"):format(lesson_count, drill_count))
