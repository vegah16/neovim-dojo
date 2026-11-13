-- Replays key solutions against running tasks. A solution is what a learner
-- would type, so a task passes here only if its text can be followed.
--
--   string             keys, with <CR>-style notation
--   function           arbitrary steps; it gets this module and types with
--                      `keys`, waits with `wait` and otherwise only reads
--   { step, step, ... } several steps; the task must not pass before the last
--   { ..., wrong = x }  x (a step or a list of steps) reaches a similar but
--                       wrong result and must not pass
--
-- A solution file has three tables. `lessons` and `drills` (scenario drills,
-- one solution per scene) use the format above. `runs` holds the drills that
-- make their rounds up as they go: a function that reads the round from the
-- buffer and types its answer, called until the drill is complete.
--
-- tests/solutions.lua holds the solutions of the built-in pack. A
-- configuration can replay that file under its own mappings and plugins.
--
-- `interactive` is a set of task IDs whose solution needs an editor with a
-- main loop: a command-line window, a label that a plugin shows after the
-- first keys, a prompt, a server. Feeding all keys in one command cannot type
-- those. `all` leaves them out and `remote` types them into a second editor.
--
-- The same solutions can be typed into a real terminal. `begin` turns one
-- into a coroutine and `next` hands its keys and waits to the driver one at a
-- time, so nothing here touches the editor in that mode: the driver types,
-- and the editor raises its own events.
local M = { terminal = false }
-- Where this file is, for the second editor of `remote`.
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local dojo = require("neovim_dojo.session")
local controls = require("neovim_dojo.controls")
local outcomes = require("neovim_dojo.outcomes")
local scenarios = require("neovim_dojo.drills.scenarios")

function M.keys(text)
  if M.terminal then
    coroutine.yield({ keys = text })
    return
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
  vim.cmd("doautocmd <nomodeline> TextChanged")
  -- Let scheduled callbacks run, as they do between a person's key presses.
  -- Plugins use them to end a state that one key started.
  vim.wait(1)
end

-- Wait for what the editor does by itself: a job, a server, a picker.
function M.wait(what, done, timeout)
  if M.terminal then
    while not done() do
      coroutine.yield({ wait = what })
    end
    return
  end
  assert(vim.wait(timeout or 10000, done, 20), "timed out waiting for " .. what)
end

-- An event that a running editor raises by itself between two keys, and one
-- command that feeds all keys at once does not.
function M.event(name)
  if not M.terminal then
    vim.cmd("doautocmd <nomodeline> " .. name)
    vim.wait(1)
  end
end

-- Run the lesson check now, as the next idle moment would.
function M.check()
  if M.terminal then
    return nil
  end
  return dojo.check()
end

-- The instruction panel of the open task as one line of text, without the
-- rail, the wrapping and the backticks of the source.
function M.panel()
  local namespace = vim.api.nvim_get_namespaces()["neovim-dojo.instructions"]
  local shown = {}
  for _, buf in ipairs(namespace and vim.api.nvim_list_bufs() or {}) do
    if vim.api.nvim_buf_is_loaded(buf) then
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        for _, line in ipairs(mark[4].virt_lines or {}) do
          for _, chunk in ipairs(line) do
            shown[#shown + 1] = chunk[1]
          end
          shown[#shown + 1] = " "
        end
      end
    end
  end
  return (table.concat(shown):gsub("│", " "):gsub("`", ""):gsub("%s+", " "))
end

-- The scene of a scenario drill that is on the screen: its place in the pool
-- and its goal. A run samples and shuffles, so the goal in the panel says
-- which round this is, and the text of the board where two scenes share a goal.
function M.scene(task)
  local panel, board = M.panel(), vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local found, goal, exact = nil, "", false
  for index, scene in ipairs(task.drill.scenes) do
    local text = controls.text(scene.goal):gsub("`", ""):gsub("%s+", " ")
    local same = vim.deep_equal(scene.lines, board)
    if panel:find(text, 1, true) and (#text > #goal or (#text == #goal and same and not exact)) then
      found, goal, exact = index, text, same
    end
  end
  return found, goal
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

-- A drill that makes its rounds up as it goes. `solver` reads one round from
-- the buffer and types its answer.
function M.run(id, solver)
  local task = assert(dojo.find_lesson(id), "no such task: " .. id)
  assert(task.kind == "drill" and task.drill.kind ~= "scenarios", id .. ": not a generated drill")
  assert(dojo.start(id), id .. ": the task did not start")
  M.keys("<Esc>")
  assert(not completed(task), id .. ": an untouched drill must not be complete")
  local ready = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  M.keys("<CR>")
  assert(not completed(task), id .. ": starting a run must not complete it")
  for _ = 1, task.drill.rounds do
    local before = M.panel()
    solver(M, task)
    assert(completed(task) or M.panel() ~= before, id .. ": the round did not advance: " .. describe())
  end
  assert(completed(task), id .. ": the drill should be complete after its rounds")
  dojo.reset()
  assert(
    vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), ready),
    id .. ": reset should return to the ready board"
  )
  dojo.quit()
end

-- What a learner does after opening the task `id`: every step of a lesson,
-- or every round of a drill until it is complete. `wrong` picks one of the
-- lesson's wrong attempts instead. Only for a driver: it yields.
function M.perform(solutions, id, wrong)
  local task = assert(dojo.find_lesson(id), "no such task: " .. id)
  local solution = solutions.lessons[id]
  if solution and wrong then
    run(assert(list(solution.wrong)[wrong], id .. ": no such wrong attempt"))
  elseif solution then
    local steps = list(solution)
    for index, step in ipairs(steps) do
      run(step)
      if index < #steps then
        coroutine.yield({ step = index, of = #steps })
      end
    end
  elseif solutions.drills[id] then
    -- Nobody starts a drill in the instant it opens. Plugins that follow
    -- the fixture, such as Git signs, need that moment to see the ready
    -- board before the first round replaces it.
    local opened = vim.uv.now()
    M.wait("a moment before the first round", function()
      return vim.uv.now() - opened > 250
    end)
    M.keys("<CR>")
    while not completed(task) do
      M.wait("a round goal in the panel", function()
        return M.scene(task) ~= nil
      end)
      local index, goal = M.scene(task)
      for _, step in ipairs(list(solutions.drills[id][index])) do
        run(step)
      end
      M.keys(controls.lhs("k"))
      M.wait("the round after " .. goal, function()
        local panel = M.panel()
        assert(not panel:find("outcome not reached", 1, true), id .. ": round not accepted: " .. goal)
        return completed(task) or not panel:find(goal, 1, true)
      end)
    end
  elseif solutions.runs and solutions.runs[id] then
    M.keys("<CR>")
    while not completed(task) do
      local before = M.panel()
      solutions.runs[id](M, task)
      M.wait("the next round", function()
        return completed(task) or M.panel() ~= before
      end)
      -- A round may end with something the drill has scheduled, such as
      -- leaving Visual mode. A person is slower than that; so is this.
      coroutine.yield({ wait = "the editor to settle" })
    end
  else
    error(id .. ": no solution to perform")
  end
end

-- Start performing `id` for a driver that types into an editor with a main
-- loop: a real terminal, or the second editor of `remote`.
local thread
function M.begin(solutions, id, wrong)
  M.terminal = true
  wrong = wrong ~= vim.NIL and wrong or nil
  thread = coroutine.create(function()
    M.perform(solutions, id, wrong)
  end)
end

-- The next thing for the driver to do: { keys = text } to type, { wait =
-- what } to ask again shortly, { step = n, of = m } after a step that must
-- not complete the lesson, { done = true } or { error = message }.
function M.next()
  if not thread or coroutine.status(thread) == "dead" then
    return { done = true }
  end
  local ok, request = coroutine.resume(thread)
  if not ok then
    local message = debug.traceback(thread, tostring(request))
    thread = nil
    return { error = message }
  end
  return request or { done = true }
end

-- Start a scenario drill so that its run plays every scene of the pool once,
-- in order. For `remote`; the first <CR> of `perform` then starts that run.
function M.open_drill(id)
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
  local started = dojo.start(id)
  dojo.options.drills = previous
  if started then
    runtime.schedule = vim.list_slice(task.drill.scenes)
  end
  return started
end

-- A second editor, started with `command` (a list that ends up in
-- `nvim --headless --embed`), that the solutions marked `interactive` are
-- typed into. It has a main loop, so it raises its own events and a solution
-- can read what a plugin shows after the first keys. `file` is the solution
-- file; the second editor loads it itself.
local Remote = {}
Remote.__index = Remote

function M.remote(command, file, options)
  options = options or {}
  local channel = vim.fn.jobstart(command, { rpc = true, env = options.env, cwd = options.cwd })
  assert(channel > 0, "the second editor did not start")
  local self = setmetatable({ channel = channel, timeout = options.timeout or 30000 }, Remote)
  self:lua(
    [[
      vim.o.columns, vim.o.lines = 120, 36
      local setup, replay, file = ...
      if type(setup) == "string" then
        assert(loadstring(setup))()
      end
      DojoReplay = dofile(replay)
      DojoReplay.terminal = true
      DojoSolutions = dofile(file)
      Dojo = require("neovim_dojo.session")
      Dojo.clear_progress(true)
      function DojoDone(id)
        return Dojo.lesson_state(Dojo.find_lesson(id)).completed
      end
    ]],
    options.setup or vim.NIL,
    source,
    vim.fn.fnamemodify(file, ":p")
  )
  return self
end

-- A request waits for as long as the editor waits at a "Press ENTER" prompt.
-- Answer that prompt first, as a person does before going on.
function Remote:lua(code, ...)
  local deadline = vim.uv.now() + self.timeout
  while vim.uv.now() < deadline do
    local mode = vim.rpcrequest(self.channel, "nvim_get_mode")
    if not mode.blocking then
      break
    elseif mode.mode:sub(1, 1) == "r" then
      vim.rpcrequest(self.channel, "nvim_input", "<CR>")
    end
    vim.wait(10)
  end
  return vim.rpcrequest(self.channel, "nvim_exec_lua", code, { ... })
end

-- Ctrl-C interrupts the moment it arrives, also the keys before it that are
-- still waiting. Send what comes before it first, as a person would have
-- typed it earlier.
function Remote:type(keys)
  local position = 1
  while position <= #keys do
    local first, last = keys:find("<C-c>", position, true)
    if first == position then
      vim.rpcrequest(self.channel, "nvim_input", "<C-c>")
      position = last + 1
    else
      vim.rpcrequest(self.channel, "nvim_input", keys:sub(position, (first or #keys + 1) - 1))
      position = first or #keys + 1
    end
    -- One request that the editor answers only after it has read the keys.
    self:lua("return true")
  end
end

function Remote:done(id)
  return self:lua("return DojoDone(...)", id)
end

-- Type one solution, or one wrong attempt, and return when its keys are in.
function Remote:perform(id, wrong, boundary)
  self:lua("DojoReplay.begin(DojoSolutions, ...)", id, wrong or vim.NIL)
  local waiting, since
  while true do
    local request = self:lua("return DojoReplay.next()")
    if request.error then
      error(id .. ": " .. request.error, 0)
    elseif request.done then
      return
    elseif request.keys then
      waiting = nil
      self:type(request.keys)
    elseif request.step then
      waiting = nil
      if boundary then
        boundary(request.step, request.of)
      end
    elseif request.wait then
      if waiting ~= request.wait then
        waiting, since = request.wait, vim.uv.now()
      end
      assert(
        vim.uv.now() - since < self.timeout,
        ("%s: timed out waiting for %s: %s"):format(id, request.wait, self:state())
      )
      vim.wait(20)
    end
  end
end

-- What the second editor shows, for a failure message.
function Remote:state()
  return self:lua([[
    return ("lines %s, cursor %s, mode %s, buffer %s"):format(
      vim.inspect(vim.api.nvim_buf_get_lines(0, 0, 30, false)),
      vim.inspect(vim.api.nvim_win_get_cursor(0)),
      vim.api.nvim_get_mode().mode,
      vim.api.nvim_buf_get_name(0)
    )
  ]])
end

function Remote:finished(id)
  local done = vim.wait(self.timeout, function()
    return self:done(id)
  end, 20)
  assert(done, id .. ": the solution did not pass: " .. self:state())
end

function Remote:lesson(id)
  assert(self:lua("return Dojo.start(...)", id), id .. ": the task did not start")
  self:type("<Esc>")
  assert(not self:lua("return Dojo.check()") and not self:done(id), id .. ": an untouched fixture must not pass")
  for attempt = 1, self:lua(
    "local wrong = DojoSolutions.lessons[...]; wrong = type(wrong) == 'table' and wrong.wrong or nil; return wrong == nil and 0 or (type(wrong) == 'table' and #wrong or 1)",
    id
  ) do
    self:perform(id, attempt)
    vim.wait(50)
    self:lua("Dojo.check()")
    assert(not self:done(id), id .. ": a wrong result passed")
    self:lua("Dojo.reset()")
    self:type("<Esc>")
  end
  self:perform(id, nil, function(step, of)
    self:lua("Dojo.check()")
    assert(not self:done(id), ("%s: passes after step %d of %d"):format(id, step, of))
  end)
  self:finished(id)
  self:lua("Dojo.reset()")
  assert(not self:lua("return Dojo.check()"), id .. ": a reset fixture must not pass")
  self:lua("Dojo.quit()")
end

function Remote:drill(id, generated)
  if generated then
    assert(self:lua("return Dojo.start(...)", id), id .. ": the task did not start")
  else
    assert(self:lua("return DojoReplay.open_drill(...)", id), id .. ": the task did not start")
  end
  self:type("<Esc>")
  assert(not self:done(id), id .. ": an untouched drill must not be complete")
  local ready = self:lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)")
  self:perform(id)
  self:finished(id)
  self:lua("Dojo.reset()")
  assert(
    vim.deep_equal(self:lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)"), ready),
    id .. ": reset should return to the ready board"
  )
  self:lua("Dojo.quit()")
end

-- Type every interactive solution, or those `only` names (a list of task
-- IDs); returns the number of lessons and drills.
function Remote:all(only)
  local ids = self:lua(
    [[
    local only = ...
    local ids = { lessons = {}, drills = {}, runs = {} }
    for id in pairs(DojoSolutions.interactive or {}) do
      if type(only) ~= "table" or vim.tbl_contains(only, id) then
      local kind = DojoSolutions.lessons[id] and "lessons" or DojoSolutions.drills[id] and "drills" or "runs"
      assert(kind ~= "runs" or DojoSolutions.runs[id], id .. ": interactive, but without a solution")
      table.insert(ids[kind], id)
      end
    end
    for _, list in pairs(ids) do
      table.sort(list)
    end
    return ids
  ]],
    only or vim.NIL
  )
  for _, id in ipairs(ids.lessons) do
    self:lesson(id)
  end
  for _, id in ipairs(ids.drills) do
    self:drill(id, false)
  end
  for _, id in ipairs(ids.runs) do
    self:drill(id, true)
  end
  return #ids.lessons, #ids.drills + #ids.runs
end

function Remote:close()
  pcall(vim.rpcnotify, self.channel, "nvim_command", "qa!")
  vim.fn.jobwait({ self.channel }, 3000)
  pcall(vim.fn.jobstop, self.channel)
end

-- Replay every solution that one command can type; returns the number of
-- lessons and drills.
function M.all(solutions)
  local interactive = solutions.interactive or {}
  local function sorted(map)
    local ids = {}
    for id in pairs(map or {}) do
      if not interactive[id] then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    return ids
  end
  local lessons, drills, runs = sorted(solutions.lessons), sorted(solutions.drills), sorted(solutions.runs)
  for _, id in ipairs(lessons) do
    M.lesson(id, solutions.lessons[id])
  end
  for _, id in ipairs(drills) do
    M.drill(id, solutions.drills[id])
  end
  for _, id in ipairs(runs) do
    M.run(id, solutions.runs[id])
  end
  return #lessons, #drills + #runs
end

return M
