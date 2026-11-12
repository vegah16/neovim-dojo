-- Replays key solutions against running tasks. A solution is what a learner
-- would type, so a task passes here only if its text can be followed.
--
--   string             keys, with <CR>-style notation
--   function           arbitrary steps
--   { step, step, ... } several steps; the task must not pass before the last
--   { ..., wrong = x }  x (a step or a list of steps) reaches a similar but
--                       wrong result and must not pass
--
-- tests/solutions.lua holds the solutions of the built-in pack. A
-- configuration can replay that file under its own mappings and plugins.
local M = {}
local dojo = require("neovim_dojo.session")
local outcomes = require("neovim_dojo.outcomes")
local scenarios = require("neovim_dojo.drills.scenarios")

function M.keys(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
  vim.cmd("doautocmd <nomodeline> TextChanged")
  -- Let scheduled callbacks run, as they do between a person's key presses.
  -- Plugins use them to end a state that one key started.
  vim.wait(1)
end

-- Run the lesson check now, as the next idle moment would.
function M.check()
  return dojo.check()
end

local function run(step)
  if type(step) == "function" then
    step(M)
  else
    M.keys(step)
  end
end

local function list(value)
  if value == nil then
    return {}
  end
  return type(value) == "table" and value or { value }
end

local function describe()
  return ("lines %s, cursor %s, search %s"):format(
    vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)),
    vim.inspect(vim.api.nvim_win_get_cursor(0)),
    vim.inspect(vim.fn.getreg("/"))
  )
end

local function completed(task)
  return dojo.lesson_state(task).completed
end

function M.lesson(id, solution)
  local task = assert(dojo.find_lesson(id), "no such task: " .. id)
  local steps = list(solution)
  assert(#steps > 0, id .. ": empty solution")
  local wrong = type(solution) == "table" and solution.wrong or nil
  assert(dojo.start(id), id .. ": the task did not start")
  -- Escape ends whatever a plugin still holds from the previous keys, such as
  -- a pending repeat of a character search. A reset through the API does not.
  M.keys("<Esc>")
  assert(not dojo.check() and not completed(task), id .. ": an untouched fixture must not pass")
  for _, attempt in ipairs(list(wrong)) do
    run(attempt)
    dojo.check()
    assert(not completed(task), id .. ": a wrong result passed: " .. describe())
    dojo.reset()
    M.keys("<Esc>")
  end
  for index, step in ipairs(steps) do
    run(step)
    dojo.check()
    if index < #steps then
      assert(not completed(task), ("%s: passes after step %d of %d"):format(id, index, #steps))
    end
  end
  assert(completed(task), id .. ": the solution did not pass: " .. describe())
  dojo.reset()
  assert(not dojo.check(), id .. ": a reset fixture must not pass")
  dojo.quit()
end

function M.drill(id, solutions)
  local task = assert(dojo.find_lesson(id), "no such task: " .. id)
  local previous, runtime = dojo.options.drills, nil
  dojo.options.drills = vim.tbl_extend("force", previous or {}, {
    scenarios = {
      new = function(context, specification, callbacks)
        runtime = scenarios.new(context, specification, callbacks)
        return runtime
      end,
    },
  })
  assert(dojo.start(id), id .. ": the task did not start")
  dojo.options.drills = previous
  local scenes = runtime.specification.scenes
  assert(#solutions == #scenes, ("%s: %d scenes but %d solutions"):format(id, #scenes, #solutions))
  -- Every scene of the pool in order, also when a run samples fewer.
  runtime.schedule = vim.list_slice(scenes)
  runtime:start()
  local checker = runtime.specification.check or outcomes.matches
  for index, scene in ipairs(scenes) do
    local where = ("%s scene %d"):format(id, index)
    assert(runtime.scene == scene, where .. ": not the expected round")
    M.keys("<Esc>")
    assert(not runtime:check(), where .. ": an untouched round must not pass")
    local steps = list(solutions[index])
    for number, step in ipairs(steps) do
      run(step)
      if number < #steps then
        assert(not checker(runtime.context, scene.check), ("%s: passes after step %d"):format(where, number))
      end
    end
    assert(checker(runtime.context, scene.check), where .. ": the solution did not pass: " .. describe())
    if scene.check.lines and vim.api.nvim_get_current_buf() == runtime.context.buf then
      local cursor = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_buf_set_lines(runtime.context.buf, -1, -1, false, { "unwanted extra edit" })
      assert(not runtime:check(), where .. ": damaged text outside the edit must fail")
      vim.api.nvim_buf_set_lines(runtime.context.buf, -2, -1, false, {})
      vim.api.nvim_win_set_cursor(0, cursor)
    end
    assert(runtime:check(), where .. ": the round should advance")
  end
  assert(runtime.phase == "finished" and completed(task), id .. ": the run should finish and complete the drill")
  dojo.reset()
  assert(runtime.phase == "ready", id .. ": reset returns to ready")
  dojo.quit()
end

-- Replay every solution; returns the number of lessons and drills.
function M.all(solutions)
  local function sorted(map)
    local ids = vim.tbl_keys(map)
    table.sort(ids)
    return ids
  end
  for _, id in ipairs(sorted(solutions.lessons)) do
    M.lesson(id, solutions.lessons[id])
  end
  for _, id in ipairs(sorted(solutions.drills)) do
    M.drill(id, solutions.drills[id])
  end
  return vim.tbl_count(solutions.lessons), vim.tbl_count(solutions.drills)
end

return M
