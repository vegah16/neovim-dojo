-- Every native outcome task: untouched fixtures fail, a real solution passes,
-- and scenario drills reject damaged text.
require("neovim_dojo").setup()
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local outcomes = require("neovim_dojo.outcomes")
local function keys(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
  vim.cmd("doautocmd <nomodeline> TextChanged")
end
local function ex(text)
  vim.cmd(text)
end
local solutions = {
  ["word-versus-big-word"] = "3w",
  ["counted-word-ends"] = "3e",
  ["line-and-exact-marks"] = function()
    keys("maG")
    dojo.check() -- typeahead suppresses CursorMoved; observe the visit explicitly
    keys("`a")
  end,
  ["compose-operator-motion"] = "d2w",
  ["operator-count-placement"] = "2d3w",
  ["dot-repeat-separated-edits"] = "ciwready<Esc>jj.",
  ["join-and-reindent"] = "Jgg=G",
  ["visual-selection-kinds"] = "Vd",
  ["visual-ends-and-reselect"] = "viwooeU",
  ["block-insert-column"] = "<C-v>jjI# <Esc>",
  ["block-delete-rectangle"] = "<C-v>jjld",
  ["literal-search-case"] = "/\\V\\CA.b<CR>",
  ["whole-word-star-hash"] = "*",
  ["search-direction-next"] = "?signal<CR>",
  ["change-next-match"] = "/\\<old\\><CR>cgnready<Esc>.",
  ["substitute-ranges"] = function()
    ex("2,3s/old/new/g")
  end,
  ["substitute-confirmation"] = ":%s/red/blue/gc<CR>yny",
  ["substitute-captures"] = function()
    ex([[1,2s/\v(\w+)[=](\d+)/\2: \1/]])
  end,
  ["bounded-global-normal"] = function()
    ex("1,4g/^TODO/normal! gUU")
  end,
}
for id, solution in pairs(solutions) do
  assert(dojo.start(id))
  assert(not dojo.check(), id .. ": untouched fixture must not pass")
  if type(solution) == "function" then
    solution()
  else
    keys(solution)
  end
  dojo.check()
  assert(
    dojo.lesson_state(dojo.find_lesson(id)).completed,
    id
      .. ": native solution failed: "
      .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
      .. " cursor "
      .. vim.inspect(vim.api.nvim_win_get_cursor(0))
  )
  dojo.quit()
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
local solutions_by_id = {
  ["word-boundary-drill"] = { "3w", "3e", "2W" },
  ["mark-edit-return-drill"] = { "maG$ciwnew<Esc>`a", "magg$ciwnew<Esc>`a", "maj0ciwnew<Esc>`a" },
  ["operator-repair-drill"] = { "d2w", 'ci"ready<Esc>', "D" },
  ["repeat-correction-drill"] = { "ciwready<Esc>jj.", "ciwdone<Esc>jj.", "ciwgo<Esc>jj." },
  ["column-patch-drill"] = { "<C-v>jjI# <Esc>", "<C-v>jjld", "<C-v>jjI> <Esc>" },
  ["selection-boundary-drill"] = { "viweU", "viwU", "VU" },
  ["search-occurrence-drill"] = { "/\\V\\CA.b<CR>", "*", "?signal<CR>" },
  ["search-change-decoys-drill"] = {
    "/\\<old\\><CR>cgnready<Esc>.",
    "/\\<cat\\><CR>cgnfox<Esc>.",
    "/\\<run\\><CR>cgnwalk<Esc>.",
  },
  ["capture-transform-drill"] = {
    [[1,2s/\v(\w+)[=](\d+)/\2: \1/]],
    [[1,2s/\v(\w+)[=](\d+)/\2: \1/]],
    [[1,2s/\v(\w+)[=](\d+)/\2: \1/]],
  },
  ["filter-repair-drill"] = { "1,3g/^TODO/normal! gUU", "1,3g/^BAD/d", "1,3v/^#/normal! A!" },
}
-- Exercise every scene independently as well as the runner's balanced lifecycle.
local runner_module = require("neovim_dojo.drills.scenarios")
for id, commands in pairs(solutions_by_id) do
  local task = dojo.find_lesson(id)
  local completed = false
  local ctx = { buf = vim.api.nvim_create_buf(true, true), lesson = task }
  vim.api.nvim_set_current_buf(ctx.buf)
  local runtime = runner_module.new(ctx, task.drill, {
    random = function(first)
      return first
    end,
    status = function() end,
    complete = function(result)
      completed = result.value == #commands and result.details.untimed
    end,
  })
  runtime:reset()
  runtime:start()
  for _ = 1, #commands do
    local scene = runtime.scene
    local index
    for i, original in ipairs(task.drill.scenes) do
      if vim.deep_equal(original, scene) then
        index = i
      end
    end
    assert(index)
    assert(not runtime:check(), id .. ": unchanged scene must not advance")
    local solution = commands[index]
    if id == "capture-transform-drill" or id == "filter-repair-drill" then
      ex(solution)
    else
      keys(solution)
    end
    assert(
      outcomes.matches(ctx, scene.check),
      id .. " scene " .. index .. ": solution mismatch: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
    )
    if scene.check.lines then
      local good = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
      vim.api.nvim_buf_set_lines(ctx.buf, -1, -1, false, { "unwanted extra edit" })
      assert(not runtime:check(), id .. ": damaged outside text must fail")
      vim.api.nvim_buf_set_lines(ctx.buf, #good, -1, false, {})
      if scene.check.cursor then
        vim.api.nvim_win_set_cursor(0, scene.check.cursor)
      end
    end
    assert(runtime:check(), id .. ": round should pass")
  end
  assert(completed and runtime.phase == "finished", id .. ": all scenes must finish")
  runtime:reset()
  assert(runtime.phase == "ready")
  runtime:close()
  vim.api.nvim_buf_delete(ctx.buf, { force = true })
end
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
  local task, commands = dojo.find_lesson(id), solutions_by_id[id]
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
print("DOJO NATIVE OUTCOMES OK: every automatic outcome, negative decoy and reset")
