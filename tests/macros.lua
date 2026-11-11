do
  require("neovim_dojo").setup()
end
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local function keys(value)
  vim.api.nvim_feedkeys(vim.keycode(value), "xt", false)
  vim.cmd("doautocmd <nomodeline> TextChanged")
  -- feedkeys has consumed the complete batch. +luafile has not returned to
  -- Neovim's input loop yet, so deliver its idle boundary explicitly.
  vim.cmd("doautocmd <nomodeline> SafeState")
end
local recording = "qa0dWgUiwI- <Esc>j0q"
vim.fn.setreg("a", "original macro")
for id, replay in pairs({ ["record-replay-macro"] = "@a@@", ["count-inspect-macro"] = "5@a" }) do
  dojo.start(id)
  keys(recording .. replay)
  dojo.check()
  assert(dojo.lesson_state(dojo.find_lesson(id)).completed, id .. " should accept real native recording and replay")
  assert(vim.fn.reg_recording() == "", "the recording must stop before replay")
  assert(vim.fn.execute("registers a"):find("dW", 1, true), ":reg a should expose the recorded motions")
  dojo.quit()
  assert(vim.fn.getreg("a") == "original macro", "each macro lesson should restore the previous macro")
end

local id = "macro-normalization-drill"
local time = 1000000000
local original_clock, original_random = dojo.options.drill_clock, dojo.options.drill_random
dojo.options.drill_clock = function()
  return time
end
dojo.options.drill_random = function(first)
  return first
end
dojo.start(id)
local buf = vim.api.nvim_get_current_buf()
local function start()
  vim.fn.maparg("<CR>", "n", false, true).callback()
end
start()
assert(vim.fn.getreg("a") == "", "a new round should require a fresh recording")
local expected = {}
for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
  expected[#expected + 1] = line == "STOP" and line or ("- " .. assert(line:match("item: (%a+)")):upper())
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, expected)
vim.fn.setreg("a", "a stale or manually supplied macro")
vim.cmd("doautocmd <nomodeline> TextChanged")
assert(
  not dojo.lesson_state(dojo.find_lesson(id)).completed,
  "final text without a fresh RecordingLeave must not finish the drill"
)
dojo.reset()
start()
keys(recording:gsub("qa", "qb", 1) .. "@b@@2@b")
assert(
  not dojo.lesson_state(dojo.find_lesson(id)).completed,
  "a recording in the wrong register must not finish the drill"
)
dojo.reset()
start()
for round = 1, 3 do
  time = time + 1000000000
  keys((round == 2 and recording:gsub("qa", "qA", 1) or recording) .. "@a@@2@a")
  if round < 3 then
    assert(vim.api.nvim_get_current_line():match("^item: "), "the next round should start on its first raw row")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "macro tail keys must not move the next board's cursor")
    assert(vim.fn.getreg("a") == "", "each round should discard the previous exercise recording")
  end
end
local result = dojo.lesson_state(dojo.find_lesson(id))
assert(
  result.completed and result.drill.runs == 1 and result.drill.last.value == 3000,
  "three macro rounds should record one timed result"
)
assert(result.drill.last.details.rows == 5, "the score should describe the five-row workload")
dojo.quit()
assert(vim.fn.getreg("a") == "original macro", "quitting the drill should restore the original macro")

for _, record_key in ipairs({ "qa", "qA" }) do
  -- Reset and quit must not leave recording active in the user's replacement view.
  dojo.start(id)
  start()
  keys(record_key)
  assert(vim.fn.reg_recording():lower() == "a", "the cancellation fixture should really be recording")
  dojo.reset()
  assert(vim.fn.reg_recording() == "", "reset should stop an owned recording")
  start()
  keys(record_key)
  dojo.quit()
  assert(vim.fn.reg_recording() == "", "quit should stop recording before returning to the original tab")
  assert(vim.fn.getreg("a") == "original macro", "cancelling a recording should restore the macro too")
  dojo.start(id)
  start()
  keys(record_key)
  vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
  assert(
    vim.wait(1000, function()
      return vim.fn.reg_recording() == "" and vim.fn.getreg("a") == "original macro"
    end),
    "external wipe should stop an owned recording and restore its register"
  )
end
dojo.options.drill_clock, dojo.options.drill_random = original_clock, original_random
print("DOJO MACROS OK")
