local a = require("neovim_dojo.author")
local w = require("neovim_dojo.workspace")
return {
  id = "windows",
  title = "Windows",
  description = "Create, navigate, normalize, and resize splits.",
  topics = { "navigation", "layout" },
  source = { kind = "vim" },
  keywords = { "split", "window" },
  lessons = {
    {
      id = "create-vertical-split",
      revision = 2,
      title = "Create a vertical split",
      objective = "Show this Dojo buffer in two side-by-side windows.",
      keywords = { "vsplit", "C-w v" },
      steps = {
        "Hold Control and press `w`, release both, then press `v`.",
        "This is the native `<C-w>v` sequence.",
      },
      hint = "`:vsplit` does the same thing. `<C-w>s` creates a horizontal split.",
      filetype = "text",
      lines = { "Create a second view of this buffer." },
      cursor = { 1, 0 },
      check = { kind = "window_count", minimum = 2 },
    },
    {
      id = "balance-splits",
      revision = 1,
      title = "Balance uneven splits",
      objective = "Make the two deliberately uneven windows equal in width.",
      keywords = { "equalize", "C-w =" },
      steps = { "Type `<C-w>=` to equalize every window in this tab." },
      hint = "Use a count with `<C-w>>` or `<C-w><` when you want a deliberate width instead.",
      filetype = "text",
      lines = { "These two views begin at different widths." },
      cursor = { 1, 0 },
      setup = { kind = "unequal_vertical_splits" },
      check = { kind = "equal_window_widths", minimum = 2 },
    },
    {
      id = "navigate-native-splits",
      revision = 3,
      title = "Navigate native splits",
      objective = "Move from the left Dojo window to the right one with a native window command.",
      keywords = { "focus", "C-w h", "C-w j", "C-w k", "C-w l" },
      steps = {
        "Type `<C-w>l` to focus the window on the right.",
        "Use `<C-w>h` whenever you want to move back to the window on the left.",
      },
      hint = "`<C-w>w` cycles through the windows of this tab, and `<C-w>p` returns to the previous one.",
      filetype = "text",
      lines = { "Move to the matching view on the right." },
      cursor = { 1, 0 },
      setup = { kind = "native_window_navigation" },
      check = { kind = "target_window" },
    },
    a.lesson(
      "close-other-windows",
      "Keep only the current window",
      "Close every other window of this tab with one command.",
      {
        "This task starts with two windows. Press `<C-w>o`: the current window becomes the only one.",
        "`:only` does the same. `<C-w>c` closes just the current window, and `<C-w>q` quits it.",
        "The buffers of the closed windows stay loaded; only their views are gone.",
      },
      { "Keep this view and close the other." },
      {
        extra = function(context)
          return #vim.api.nvim_tabpage_list_wins(context.tab) == 1
        end,
      },
      { setup = { kind = "unequal_vertical_splits" }, keywords = { "C-w o", ":only", "C-w c", "C-w q" } }
    ),
    a.lesson(
      "move-window-to-tab",
      "Move a window into its own tab page",
      "Move one of the two windows to a new tab page, then come back to this tab.",
      {
        "Press `<C-w>T`. The current window leaves this tab and becomes the only window of a new tab page.",
        "Return with `gT`, the previous tab page. This tab now has one window and the other tab still shows the buffer.",
        "A tab page is a layout of windows, not a file. `:tabclose` closes one.",
      },
      { "One of these two views can have a tab page of its own." },
      {
        extra = function(context)
          if #vim.api.nvim_tabpage_list_wins(context.tab) ~= 1 then
            return false
          end
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            if tab ~= context.tab then
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                if vim.api.nvim_win_get_buf(win) == context.buf then
                  return true
                end
              end
            end
          end
          return false
        end,
      },
      { setup = { kind = "native_window_navigation" }, keywords = { "C-w T", "gT", "gt", ":tabclose", "tab page" } }
    ),
    w.lesson(
      "tab-pages-navigate",
      "Open and switch tab pages",
      "Open `alpha.txt` in a new tab page, then return to this tab and leave the new one open.",
      {
        "Run `:tabedit alpha.txt`. A new tab page opens to the right with that file.",
        "`gt` goes to the next tab page and `gT` to the previous one; with a count, `2gt` goes to tab page 2. Return with `gT`.",
        "`:tabs` lists the tab pages and `:tabonly` closes all the others. The extra tab is closed when you quit this task.",
      },
      { "Tab pages hold layouts: this one stays as it is." },
      {
        position = { file = "main.txt" },
        extra = function(context)
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            if tab ~= context.tab then
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == w.path(context, "alpha.txt") then
                  return true
                end
              end
            end
          end
          return false
        end,
      },
      { files = { ["alpha.txt"] = { "alpha reference" } } },
      { keywords = { ":tabedit", ":tabnew", "gt", "gT", ":tabs", ":tabonly" } }
    ),
    w.lesson(
      "open-file-under-cursor",
      "Open the file under the cursor",
      "Open the file named in the text with `gf`, then return to this file.",
      {
        "The cursor is on the path `src/keep.txt`. Press `gf` to edit that file.",
        "Return with `<C-^>`, the alternate file, or with `<C-o>`.",
        "`<C-w>f` opens the file in a split and `<C-w>gf` in a new tab page. `gF` also jumps to a line number that follows the name.",
      },
      { "See src/keep.txt for the details." },
      { visited = { "src/keep.txt" }, position = { file = "main.txt" } },
      { files = { ["src/keep.txt"] = { "the details" } } },
      { cursor = { 1, 6 }, keywords = { "gf", "gF", "C-w f", "C-w gf", "C-^" } }
    ),
    {
      id = "resize-split-with-count",
      revision = 1,
      title = "Resize a split by a count",
      objective = "Make the left window narrower with a counted resize command.",
      keywords = { "resize", "C-w <", "C-w >", "C-w +", "C-w -", "C-w |", "C-w _" },
      steps = {
        "Type `10<C-w><` to make the current window ten columns narrower. `<C-w>>` makes it wider.",
        "`<C-w>+` and `<C-w>-` change the height. `<C-w>|` and `<C-w>_` give the window all the width or height, and `<C-w>=` evens everything out.",
      },
      hint = "`:vertical resize 40` sets an exact width.",
      filetype = "text",
      lines = { "Shrink this left-hand view by ten columns." },
      cursor = { 1, 0 },
      setup = { kind = "resize_vertical_splits" },
      check = { kind = "window_narrower" },
    },
  },
}
