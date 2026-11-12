-- Every native outcome task, replayed with the keys of tests/solutions.lua:
-- untouched fixtures fail, intermediate steps and wrong results fail, a real
-- solution passes, and scenario drills reject damaged text.
require("neovim_dojo").setup()
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local replay = dofile("tests/replay.lua")
local keys = replay.keys
local solutions = dofile("tests/solutions.lua")
local lesson_count, drill_count = replay.all(solutions)
-- Every task is replayed above, completed by hand, or covered by another file.
do
  local covered = {}
  for _, id in ipairs(vim.list_extend(vim.list_extend({}, solutions.manual), solutions.elsewhere)) do
    assert(dojo.find_lesson(id), "solutions.lua names an unknown task: " .. id)
    covered[id] = true
  end
  for _, task in ipairs(dojo.lessons()) do
    local replayed = solutions.lessons[task.id] or solutions.drills[task.id]
    assert(replayed or covered[task.id], task.id .. ": no solution in tests/solutions.lua")
    assert(not (replayed and covered[task.id]), task.id .. ": listed twice in tests/solutions.lua")
    if vim.tbl_contains(solutions.manual, task.id) then
      assert(task.check.kind == "manual", task.id .. ": listed as manual but has a check")
    end
  end
end
dojo.clear_progress(true)
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
print(("DOJO NATIVE OUTCOMES OK: %d lessons and %d drills replayed with real keys"):format(lesson_count, drill_count))
