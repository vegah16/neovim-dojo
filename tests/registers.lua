do
  require("neovim_dojo").setup()
end
local dojo = require("neovim_dojo.session")
dojo.clear_progress(true)
local function normal(keys)
  vim.cmd.normal({ args = { keys }, bang = true })
  vim.cmd("doautocmd <nomodeline> TextChanged")
end
local function completed(id)
  dojo.check()
  assert(dojo.lesson_state(dojo.find_lesson(id)).completed, id .. " should recognize its native outcome")
end

vim.fn.setreg("a", { "saved macro", "saved text" }, "V")
local saved_a = vim.fn.getreginfo("a")
dojo.start("append-named-register")
normal('"ayyj"AyyG"ap')
assert(
  vim.deep_equal(vim.fn.getreg("a", 1, true), { "amber", "gold" }),
  "uppercase append should build a linewise collection"
)
completed("append-named-register")
dojo.quit()
assert(
  vim.deep_equal(vim.fn.getreginfo("a"), saved_a),
  "closing the lesson should restore the named register and its type"
)

dojo.start("retrieve-yank-register")
normal("yiwjdd")
assert(vim.fn.getreg("0") == "amber" and vim.fn.getreg('"') ~= "amber", "a delete should leave the yank in 0")
normal('viw"0p')
completed("retrieve-yank-register")
dojo.quit()

dojo.start("inspect-registers")
assert(vim.fn.execute("registers a"):find("saved macro", 1, true), ":reg a should expose the actual named register")
assert(not dojo.check(), "register inspection should remain an explicit observational lesson")
dojo.quit()

for _, name in ipairs({ "a", "b", "c" }) do
  vim.fn.setreg(name, "before " .. name)
end
for number = 1, 9 do
  vim.fn.setreg(tostring(number), "saved deletion " .. number)
end
local time = 1000000000
local old_clock, old_random = dojo.options.drill_clock, dojo.options.drill_random
dojo.options.drill_clock = function()
  return time
end
dojo.options.drill_random = function(first)
  return first
end
local id = "named-register-recall-drill"
dojo.start(id)
local buf = vim.api.nvim_get_current_buf()
vim.fn.maparg("<CR>", "n", false, true).callback()
local token = vim.api.nvim_get_current_line():match("token = (%a+)")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "token = " .. token, "recalled = " .. token })
vim.cmd("doautocmd <nomodeline> TextChanged")
assert(
  not dojo.lesson_state(dojo.find_lesson(id)).completed,
  "typing final text without a named yank and deletion must not finish the drill"
)
dojo.reset()
vim.fn.maparg("<CR>", "n", false, true).callback()
local namespace = vim.api.nvim_get_namespaces()["neovim-dojo.instructions"]
local seen = {}
for _ = 1, 3 do
  local mark = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })[1]
  local panel = {}
  for _, line in ipairs(mark[4].virt_lines) do
    for _, chunk in ipairs(line) do
      panel[#panel + 1] = chunk[1]
    end
  end
  local name = assert(table.concat(panel):match("save in register ([a-z]),"))
  seen[name] = true
  time = time + 1000000000
  normal('"' .. name .. 'yiwjdd$viw"' .. name .. "p")
end
local result = dojo.lesson_state(dojo.find_lesson(id))
assert(
  result.completed and result.drill.runs == 1 and result.drill.last.value == 3000,
  "three genuine recalls should record one timed run"
)
assert(seen.a and seen.b and seen.c, "the balanced run should exercise every requested register")
dojo.quit()
for _, name in ipairs({ "a", "b", "c" }) do
  assert(vim.fn.getreg(name) == "before " .. name, "quit should restore each register owned by the drill")
end
for number = 1, 9 do
  assert(
    vim.fn.getreg(tostring(number)) == "saved deletion " .. number,
    "the deletion history should survive the exercise"
  )
end

dojo.start(id)
vim.fn.setreg("a", "temporary exercise content")
vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
assert(
  vim.wait(1000, function()
    return vim.fn.getreg("a") == "before a"
  end),
  "external wipe should restore saved registers too"
)
dojo.options.drill_clock, dojo.options.drill_random = old_clock, old_random
print("DOJO REGISTERS OK")
