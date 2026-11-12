-- The real Snacks picker, opened headless. Needs a snacks.nvim checkout:
--   DOJO_TEST_SNACKS=/path/to/snacks.nvim tests/run.sh tests/picker_snacks.lua
local snacks_dir = vim.env.DOJO_TEST_SNACKS
if not snacks_dir or snacks_dir == "" then
  print("DOJO SNACKS PICKER SKIPPED: set DOJO_TEST_SNACKS to a snacks.nvim checkout")
  return
end
assert(vim.fn.isdirectory(snacks_dir .. "/lua/snacks") == 1, "DOJO_TEST_SNACKS is not a snacks.nvim checkout")
vim.opt.runtimepath:append(snacks_dir)
vim.o.columns, vim.o.lines = 160, 40
require("snacks").setup({ picker = { enabled = true } })
local dojo = require("neovim_dojo")
dojo.setup()
local session = dojo.session
session.clear_progress(true)
local ui = require("neovim_dojo.ui.snacks")
ui.reset_filters()

local function current()
  return Snacks.picker.get({ source = "neovim_dojo" })[1]
end
local function wait(condition, message)
  assert(vim.wait(5000, condition, 20), message)
end
local function open()
  session.open()
  wait(function()
    local picker = current()
    return picker and not picker:is_active() and picker.list:count() > 0
  end, "the Dojo picker should open and finish listing")
  return current()
end
local function keys(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
end
-- Replace the search text with real keys. A nested feedkeys never reaches the
-- main loop's TextChanged check, so that event is sent by hand.
local function search(text)
  vim.cmd.stopinsert()
  keys("cc" .. text)
  vim.cmd("doautocmd <nomodeline> TextChanged")
end
local function input_text(picker)
  local namespace = vim.api.nvim_get_namespaces()["snacks.picker.input"]
  local mark = vim.api.nvim_buf_get_extmarks(picker.input.win.buf, namespace, 0, -1, { details = true })[1]
  return table.concat(vim.tbl_map(function(chunk)
    return chunk[1]
  end, mark[4].virt_text))
end
local function selected_task(picker)
  local item = picker:current()
  return item and item.lesson
end

-- Rows, the shown/total count and the preview come from real Snacks objects.
local picker = open()
local total = #session.lessons() + 1
assert(#picker:items() == total and picker:items()[1].guide, "the key guide and every task are listed")
assert(input_text(picker) == ("%d/%d "):format(total, total), "the input shows shown/total: " .. input_text(picker))
assert(picker:current().guide, "the key guide is selected first")
wait(function()
  local buf = picker.preview.win.buf
  return buf
    and vim.api.nvim_buf_is_valid(buf)
    and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("Neovim Dojo picker keys", 1, true)
end, "the key guide is previewed")
for _, key in ipairs({ ",f", ",x", ",s", ",v", ",i", ",a", ",m", ",M", "<Tab>", "j", "k" }) do
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert(mapping.buffer == 1, "the input window maps " .. key .. " in Normal mode")
end
assert(vim.fn.maparg(",n", "n") == "", "path resume is unmapped without an active path")
assert(vim.fn.maparg(",f", "i") == "", "typing a comma in the search box must not wait for a mapping")

-- A search narrows the rows but keeps the catalogue total.
search("balance splits")
wait(function()
  return picker.list:count() < total and picker.list:count() > 0 and not picker:is_active()
end, "typing filters the rows")
wait(function()
  return input_text(picker) == ("%d/%d "):format(picker.list:count(), total)
end, "the count keeps the catalogue total while searching")
assert(selected_task(picker).id == "balance-splits", "the best match is selected")

-- Real keys: complete, star, select and bulk-set.
keys(",m")
assert(session.lesson_state(session.find_lesson("balance-splits")).completed, ",m completes the selected task")
keys(",s")
assert(session.lesson_state(session.find_lesson("balance-splits")).favorite, ",s stars it")
keys(",s,m")
search("")
wait(function()
  return picker.list:count() == total and not picker:is_active()
end, "an empty search shows everything again")
keys("j")
local second = selected_task(picker)
assert(second and second.id == session.lessons()[1].id, "j moves to the first task")
keys("<Tab>")
assert(#picker:selected() == 1 and selected_task(picker).id == second.id, "Tab selects without moving")
wait(function()
  return input_text(picker) == ("(1) %d/%d "):format(total, total)
end, "the count shows the selection")
local select, prompt = vim.ui.select, nil
vim.ui.select = function(_, options, choose)
  prompt = options.prompt
  choose("complete")
end
keys(",M")
wait(function()
  return prompt ~= nil and session.lesson_state(second).completed
end, ",M sets the selected task")
vim.ui.select = select
assert(prompt == "Set 1 selected tasks", "bulk completion reads the real selection")
wait(function()
  local reopened = current()
  return reopened and reopened ~= picker and not reopened:is_active() and reopened.list:count() == total
end, "the catalogue reopens after a bulk change")
picker = current()

-- A facet changes the list title; `,x` restores the default in place.
ui.set_filter("completion", "complete")
picker:close()
picker = open()
assert(picker.list:count() == 2 and #picker:items() == 2, "the complete view lists the guide and one task")
assert(input_text(picker) == ("2/%d "):format(total), "a facet narrows shown, not total")
vim.cmd.stopinsert()
keys(",x")
wait(function()
  return picker.list:count() == total and not picker:is_active()
end, ",x shows every available task again")
assert(vim.deep_equal(ui.active_filters(), { availability = "available" }))

-- Enter starts the selected task and closes the picker.
keys("j<CR>")
wait(function()
  return vim.api.nvim_buf_get_name(0) == "neovim-dojo://" .. second.id and current() == nil
end, "Enter starts the task")
session.quit()
session.clear_progress(true)
ui.reset_filters()
print("DOJO SNACKS PICKER OK")
