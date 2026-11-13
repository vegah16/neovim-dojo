-- The panel in a small window: GOAL, HOW and the fixture stay on the screen
-- for every task, the panel follows the window it is read in, and `,h`
-- opens the whole text when the window cannot hold it.
local dojo = require("neovim_dojo")
dojo.setup({})
local session = dojo.session
session.clear_progress(true)

local function screen()
  vim.cmd("redraw")
  local rows = {}
  for row = 1, vim.o.lines do
    local cells = {}
    for column = 1, vim.o.columns do
      cells[column] = vim.fn.screenstring(row, column)
    end
    rows[row] = table.concat(cells)
  end
  return table.concat(rows, "\n")
end

local function panel(buf)
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

local function widest(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

-- Let the deferred fit run, as the main loop does after a window command.
local function settle()
  vim.cmd("redraw")
  vim.cmd("doautocmd <nomodeline> WinResized")
  vim.wait(20)
end

-- Every native task, in a small terminal and in an ordinary one.
for _, size in ipairs({ { 24, 80 }, { 40, 140 } }) do
  vim.o.lines, vim.o.columns = size[1], size[2]
  local full = 0
  for _, task in ipairs(session.lessons()) do
    assert(session.start(task.id), task.id .. " should start")
    local shown = screen()
    local where = ("%s at %dx%d"):format(task.id, size[2], size[1])
    assert(shown:find("│ GOAL", 1, true), where .. " should open with GOAL on the screen")
    assert(shown:find("│ HOW", 1, true), where .. " should open with HOW on the screen")
    assert(shown:find("EXERCISE ─", 1, true), where .. " should open with the fixture divider on the screen")
    assert(
      vim.fn.line("w0") <= vim.fn.line(".") and vim.fn.line(".") <= vim.fn.line("w$"),
      where .. " should open with the cursor line of the fixture on the screen"
    )
    if session.panel_layout() == "full" then
      full = full + 1
    end
    session.quit()
  end
  if size[1] == 40 then
    assert(full == #session.lessons(), "an ordinary terminal shows every task with its full panel")
  else
    assert(full > 0 and full < #session.lessons(), "a small terminal shortens only the panels that do not fit")
  end
end

-- The panel is laid out for the window the learner is in, not the narrowest.
vim.o.lines, vim.o.columns = 40, 140
for _, id in ipairs({ "balance-splits", "close-other-windows" }) do
  assert(session.start(id))
  local buf = vim.api.nvim_get_current_buf()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  assert(#windows == 2, id .. " starts with two windows")
  local other = windows[1] == vim.api.nvim_get_current_win() and windows[2] or windows[1]
  assert(
    vim.api.nvim_win_get_width(0) > vim.api.nvim_win_get_width(other),
    id .. " starts in the wide window, where the panel can be read"
  )
  assert(widest(panel(buf)) > 60, id .. " wraps the panel to the wide window")
  assert(widest(panel(buf)) <= vim.api.nvim_win_get_width(0), id .. " keeps the panel inside the wide window")
  assert(screen():find("│ GOAL", 1, true), id .. " opens with GOAL on the screen")
  session.quit()
end

-- Entering a narrower window wraps the panel for it; coming back widens it.
vim.o.lines, vim.o.columns = 40, 100
assert(session.start("balance-splits"))
local buf = vim.api.nvim_get_current_buf()
vim.cmd("wincmd p")
vim.cmd("vertical resize 40")
settle()
assert(widest(panel(buf)) <= 40 - 8, "the panel is wrapped again for the window that was entered")
assert(screen():find("│ GOAL", 1, true), "the narrower window still shows GOAL")
vim.cmd("wincmd p")
settle()
assert(widest(panel(buf)) > 40, "and again for the wide window on the way back")
-- A window that has scrolled away from the panel keeps its view.
vim.cmd("only")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn["repeat"]({ "line" }, 200))
vim.api.nvim_win_set_cursor(0, { 150, 0 })
vim.cmd("normal! zt")
vim.cmd("redraw")
local top = vim.fn.line("w0")
assert(top == 150)
vim.cmd("vsplit")
settle()
assert(vim.fn.line("w0") == top, "fitting the panel again does not scroll a window that left it")
session.quit()

-- `,h` in a window too small for the whole panel opens it in a window of
-- its own, hint and every control included; `q` closes that window.
vim.o.lines, vim.o.columns = 24, 80
assert(session.start("inspect-registers"))
buf = vim.api.nvim_get_current_buf()
local short = table.concat(panel(buf), "\n")
assert(session.panel_layout() ~= "full", "five long steps do not fit a small terminal in full")
assert(short:find(",h hint and all keys", 1, true), "the short panel names ,h")
assert(not short:find(",v toggle", 1, true), "the short panel leaves the other controls to ,h")
vim.fn.maparg(",h", "n", false, true).callback()
local help = vim.api.nvim_get_current_buf()
assert(help ~= buf and vim.api.nvim_win_get_config(0).relative == "editor", ",h opens a window of its own")
-- One paragraph per section, so that a phrase is found across a line break.
local text = table.concat(vim.api.nvim_buf_get_lines(help, 0, -1, false), "\n"):gsub("\n│%s+", " ")
for _, expected in ipairs({ "NEOVIM DOJO", "GOAL", "HINT", ",v toggle verification", ",q quit" }) do
  assert(text:find(expected, 1, true), "the ,h window should show " .. expected)
end
assert(vim.fn.maparg(",r", "n", false, true).buffer == 1, "the task controls work in the ,h window")
vim.fn.maparg("q", "n", false, true).callback()
assert(vim.api.nvim_get_current_buf() == buf, "q returns to the task")
session.quit()

-- In a window that holds the whole panel, `,h` shows the hint in place.
vim.o.lines, vim.o.columns = 40, 140
assert(session.start("inspect-registers"))
buf = vim.api.nvim_get_current_buf()
vim.fn.maparg(",h", "n", false, true).callback()
assert(vim.api.nvim_get_current_buf() == buf, "a spacious window opens no extra window")
assert(table.concat(panel(buf), "\n"):find("│ HINT", 1, true), "and shows the hint in the panel")
session.quit()
-- Wiping the task's buffer by hand ends the task without an error from the
-- window events of the closing tab.
assert(session.start("balance-splits"))
buf = vim.api.nvim_get_current_buf()
vim.v.errmsg = ""
vim.api.nvim_buf_delete(buf, { force = true })
vim.wait(20)
assert(vim.v.errmsg == "", "wiping the task buffer raised: " .. vim.v.errmsg)
assert(session.panel_layout() == nil, "no task is open after the wipe")
print("DOJO PANEL OK")
