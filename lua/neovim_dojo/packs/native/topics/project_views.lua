local w = require("neovim_dojo.workspace")
local files =
  { ["alpha.txt"] = { "alpha reference" }, ["beta.txt"] = { "beta notes" }, ["src/keep.txt"] = { "protected" } }
return {
  id = "project-views",
  title = "Project Views",
  description = "Keep edits safe across file buffers, split layouts, tabs and directory scopes.",
  source = { kind = "vim" },
  topics = { "buffers", "windows", "projects" },
  lessons = {
    w.lesson(
      "modified-buffer-safe-close",
      "Modified buffers and safe closing",
      "Keep an unsaved edit while closing one of the two windows that show it.",
      {
        "This task starts with two views of `main.txt`. Append ` retained` to the first line; both views show it because they display one buffer.",
        "Close one view with `:close`. The modified buffer stays loaded in the other window, and `:ls` marks it with `+`.",
        "`:bdelete` refuses a modified buffer and `:bdelete!` discards its changes; use neither here. Finish with one view of `main.txt` and `notes retained` still in memory. Saving is optional.",
      },
      { "notes" },
      { files = { ["main.txt"] = { "notes retained" } }, layout = { count = 1 }, position = { file = "main.txt" } },
      { files = files, model = "split" },
      { revision = 2 }
    ),
    w.lesson(
      "two-views-one-file",
      "Two views of one file",
      "Edit once and see the same text buffer in two vertical views.",
      {
        "Use `<C-w>v`, then append ` shared` to `notes` in either view.",
        "Both windows show the same buffer; cursor and scrolling are window-local. Finish with two side-by-side views.",
      },
      { "notes" },
      { files = { ["main.txt"] = { "notes shared" } }, layout = { count = 2, same_buffer = true, vertical = true } },
      { files = files }
    ),
    w.lesson(
      "exchange-split-positions",
      "Move and exchange splits",
      "Move the second file view to the left of the main file view.",
      {
        "Open `:rightbelow vsplit alpha.txt`. The new view opens to the right of main, whatever 'splitright' says.",
        "Use `<C-w>H` to move that file view to the far left. `<C-w>x` exchanges windows; uppercase H/J/K/L move a split to an edge. Finish with alpha left and main right.",
      },
      { "main" },
      {
        layout = { count = 2, vertical = true },
        extra = function(c)
          local wins = vim.api.nvim_tabpage_list_wins(c.tab)
          table.sort(wins, function(a, b)
            return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
          end)
          return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(wins[1])) == w.path(c, "alpha.txt")
            and vim.api.nvim_win_get_buf(wins[2]) == c.buf
        end,
      },
      { files = files },
      { revision = 2 }
    ),
    w.lesson(
      "tab-local-directory",
      "Tab-local versus process directory",
      "Set only this tab to the fixture src directory.",
      {
        "Inspect `:pwd`, `:echo getcwd(-1,-1)` and `:echo haslocaldir(-1)` to compare effective and global directories. Neovim checks tab scope only with the -1 argument.",
        "Run `:tcd src`. `:cd` changes process scope, `:tcd` tab scope, and `:lcd` window scope.",
        "This task begins with a fixture-local tab directory. The surrounding editor tab is preserved on quit.",
      },
      { "directory scope" },
      { tcd = "src" },
      { files = files }
    ),
    w.drill(
      "reconstruct-layout-drill",
      "Reconstruct requested layouts",
      "Build different views while retaining a protected file and all edits.",
      {
        "The round tells you the required layout. Use native split commands, not extra editor instances.",
      },
      {
        {
          goal = "Create two vertical views of main.txt",
          lines = { "vertical view" },
          check = {
            layout = { count = 2, same_buffer = true, vertical = true },
            files = {
              ["main.txt"] = { "vertical view" },
            },
          },
        },
        {
          goal = "Create three views of main.txt, any split arrangement",
          lines = { "three views" },
          check = { layout = { count = 3, same_buffer = true }, files = { ["main.txt"] = { "three views" } } },
        },
        {
          goal = "Start with two views; close one, keep main.txt intact",
          model = "split",
          lines = { "single view" },
          check = { layout = { count = 1, same_buffer = true }, files = { ["main.txt"] = { "single view" } } },
        },
      },
      { files = files }
    ),
    w.drill(
      "retrieve-working-set-drill",
      "Retrieve a working set",
      "Visit two files across a tab/split boundary and return without losing the unsaved main edit.",
      {
        "Append the requested suffix to main, visit both named files (one in a new tab with `:tabedit`), then return to main.",
        "Quit retires tabs containing only fixture files; outside tabs and mixed views are preserved.",
      },
      {
        {
          goal = "Append A to main; visit alpha.txt and beta.txt; return",
          lines = { "notes" },
          check = {
            files = { ["main.txt"] = { "notesA" }, ["src/keep.txt"] = { "protected" } },
            visited = { "alpha.txt", "beta.txt" },
            position = { file = "main.txt" },
          },
        },
        {
          goal = "Append B to main; visit beta.txt and src/keep.txt; return",
          lines = { "notes" },
          check = {
            files = { ["main.txt"] = { "notesB" }, ["alpha.txt"] = { "alpha reference" } },
            visited = { "beta.txt", "src/keep.txt" },
            position = { file = "main.txt" },
          },
        },
      },
      { files = files }
    ),
  },
}
