-- A running task: its panel, completion, review state, drill results, the
-- commands, the dependency-free picker and the idea file.
vim.o.columns = 200 -- wide enough that a split does not wrap the panel
local ideas_path = vim.fn.tempname() .. "-ideas/IDEAS.md"
local dojo = require("neovim_dojo")
dojo.setup({ ideas_path = ideas_path, mappings = { open = "<leader>D" } })
local session = dojo.session
session.clear_progress(true)

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

for _, command in ipairs({ "NeovimDojo", "NeovimDojoReset", "NeovimDojoIdea", "NeovimDojoIdeas" }) do
  assert(vim.fn.exists(":" .. command) == 2, command .. " should exist after setup")
end
assert(
  vim.fn.maparg("<leader>D", "n", false, true).desc == "Open Neovim Dojo",
  "the open mapping is optional and configurable"
)

-- A lesson: instructions, automatic completion and canonical status.
local before_tabs = #vim.api.nvim_list_tabpages()
vim.cmd("NeovimDojo create-vertical-split")
local buf = vim.api.nvim_get_current_buf()
local lesson = session.find_lesson("create-vertical-split")
assert(vim.api.nvim_buf_get_name(buf) == "neovim-dojo://create-vertical-split", "a task buffer is named after its ID")
assert(vim.bo[buf].buftype == "nofile" and not vim.bo[buf].swapfile, "a task buffer is disposable")
local text = table.concat(panel(buf), "\n")
for _, expected in ipairs({
  "NEOVIM DOJO",
  "LESSON · Create a vertical split",
  "│ GOAL",
  "│ HOW",
  "│ CONTROLS",
  "│ STATUS",
}) do
  assert(text:find(expected, 1, true), "the panel should show " .. expected)
end
assert(
  vim.tbl_contains(panel(buf), "│   Complete: no · Verified: no"),
  "a new task is neither complete nor verified"
)
assert(not text:find("Last:", 1, true), "a lesson never shows a drill result")
assert(not text:find("HINT", 1, true), "the hint is hidden until asked for")
vim.fn.maparg(",h", "n", false, true).callback()
assert(table.concat(panel(buf), "\n"):find("│ HINT", 1, true), "the hint key reveals the hint")
assert(not session.check(), "an untouched fixture must not pass")
vim.cmd.vsplit()
assert(session.check(), "the native outcome completes the lesson")
assert(vim.tbl_contains(panel(buf), "│   Complete: yes · Verified: no"), "status is derived from stored state")
assert(
  session.verify_current() and session.review_status(lesson) == "verified",
  "verification is separate from completion"
)
assert(vim.tbl_contains(panel(buf), "│   Complete: yes · Verified: yes"))
session.reset()
assert(#vim.api.nvim_tabpage_list_wins(0) == 1, "reset rebuilds the fixture")
assert(session.lesson_state(lesson).completed, "reset keeps recorded progress")
session.quit()
assert(
  #vim.api.nvim_list_tabpages() == before_tabs and not vim.api.nvim_buf_is_valid(buf),
  "quit removes the task tab and buffer"
)
assert(
  not session.start("no-such-task") and #vim.api.nvim_list_tabpages() == before_tabs,
  "an unknown task starts nothing"
)

-- A timed drill: Last and Best stay on screen after the run.
local time = 1000000000
session.options.drill_clock = function()
  return time
end
session.options.drill_random = function(first)
  return first
end
local drill = session.find_lesson("hjkl-target-grid")
assert(session.start(drill.id))
buf = vim.api.nvim_get_current_buf()
local targets = vim.api.nvim_get_namespaces()["neovim-dojo.drill-target"]
local function run(duration)
  local started = time
  vim.fn.maparg("<CR>", "n", false, true).callback()
  local active = table.concat(panel(buf), "\n")
  assert(
    active:find("│ STATUS", 1, true) and not active:find("│ GOAL", 1, true),
    "a running drill collapses its panel"
  )
  for round = 1, drill.drill.rounds do
    local marks = vim.api.nvim_buf_get_extmarks(buf, targets, 0, -1, {})
    assert(#marks == 1, "a running drill shows exactly one target")
    if round == drill.drill.rounds then
      time = started + duration
    end
    vim.api.nvim_win_set_cursor(0, { marks[1][2] + 1, marks[1][3] })
    vim.cmd("doautocmd <nomodeline> CursorMoved")
  end
end
run(2500000000)
assert(
  vim.tbl_contains(panel(buf), "│   Last: 2.50 s · Best: 2.50 s"),
  "a finished drill shows its result under STATUS"
)
time = time + 1000000000
run(3000000000)
assert(vim.tbl_contains(panel(buf), "│   Last: 3.00 s · Best: 2.50 s"), "a slower replay keeps the personal best")
local record = session.lesson_state(drill).drill
assert(record.runs == 2 and record.best.value == 2500 and record.last.value == 3000, "results are stored per task")
session.quit()
session.options.drill_clock, session.options.drill_random = nil, nil

-- The dependency-free picker lists available tasks and starts the chosen one.
local select = vim.ui.select
local offered
vim.ui.select = function(items, options, choose)
  offered = { items = items, label = options.format_item(items[1]) }
  choose(items[2])
end
vim.cmd("NeovimDojo")
vim.ui.select = select
assert(
  #offered.items == #session.lessons() and offered.label:find(offered.items[1].title, 1, true),
  "the picker lists tasks"
)
assert(vim.api.nvim_buf_get_name(0) == "neovim-dojo://" .. offered.items[2].id, "choosing a task starts it")
session.quit()

-- Ideas go to the configured Markdown file.
vim.cmd("NeovimDojoIdea Teach text objects")
local written = table.concat(vim.fn.readfile(ideas_path), "\n")
assert(written:find("## Teach text objects", 1, true) and written:find("Status: idea", 1, true), "an idea is appended")
vim.fn.delete(vim.fs.dirname(ideas_path), "rf")

-- Progress reset keeps review state.
assert(session.clear_progress(true))
assert(not session.lesson_state(lesson).completed and session.review_status(lesson) == "verified")
session.clear_review(lesson)
print("DOJO SESSION OK")
