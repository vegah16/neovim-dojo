local a = require("neovim_dojo.author")
return {
  id = "command-line-editing",
  title = "Command-line Editing",
  description = "Use Neovim's modal command and search-history windows.",
  topics = { "history", "editing" },
  source = { kind = "vim" },
  keywords = { "command-line-window", "history" },
  lessons = {
    {
      id = "open-command-history",
      revision = 2,
      title = "Open command history",
      objective = "Open the Ex command-line window and inspect commands as an editable buffer.",
      keywords = { "q:" },
      steps = {
        "Press `q:` to open command history in the command-line window.",
        "Move with Normal-mode motions; press `<CR>` to execute a harmless entry or `<C-c><Esc>` to cancel. Ctrl-C returns to the command line; Escape cancels that pending command.",
      },
      hint = "The command-line window supports ordinary motions, operators, undo, and paste.",
      filetype = "text",
      lines = { "Open command history without changing this disposable buffer." },
      cursor = { 1, 0 },
      check = { kind = "cmdwin_types", types = { ":" } },
    },
    {
      id = "edit-partial-command",
      revision = 1,
      title = "Edit a partial command",
      objective = "Move a partially typed Ex command into the command-line window for modal editing.",
      keywords = { ":C-f", "C-f" },
      steps = {
        "Type `:echo 'Neovim Dojo'` but do not press `<CR>`.",
        "Press `<C-f>` to move that text into the command-line window, edit it with Normal/Insert mode, then press `<CR>`.",
      },
      hint = "Unlike `q:`, `<C-f>` preserves the command you already started typing.",
      filetype = "text",
      lines = { "Draft a command below, then promote it to a real editable buffer." },
      cursor = { 1, 0 },
      check = { kind = "cmdwin_text", type = ":", text = "Neovim Dojo" },
    },
    {
      id = "open-search-history",
      revision = 2,
      title = "Open both search histories",
      objective = "Open the forward and backward search-history windows with their native commands.",
      keywords = { "q/", "q?", "/C-f", "?C-f" },
      steps = {
        "Press `q/` to open forward-search history, inspect it, then press `<C-c><Esc>` to cancel. Ctrl-C returns to the pending search; Escape cancels it.",
        "Press `q?` to open backward-search history; use `<CR>` on an entry or `<C-c><Esc>` to cancel and return.",
      },
      hint = "While already typing `/` or `?`, `<C-f>` moves that partial search into the same window.",
      filetype = "text",
      lines = {
        "A lantern hangs above the northern door.",
        "Search history is editable without changing this text.",
        "A second lantern hangs beside the southern door.",
      },
      cursor = { 2, 0 },
      check = { kind = "cmdwin_types", types = { "/", "?" } },
    },
    a.lesson(
      "cmdline-word-under-cursor",
      "Put the word under the cursor on the command line",
      "Rename `counter` to `total` in the first two lines, without typing `counter`.",
      {
        "The cursor is on `counter`. Type `:1,2s/` and press `<C-r><C-w>`: the word under the cursor is inserted.",
        "Finish the command as `:1,2s/counter/total/g` and press `<CR>`.",
        "`<C-r><C-a>` inserts the WORD, and `<C-r><C-l>` the whole line.",
      },
      { "rename counter here", "counter = counter + 1", "# counter stays" },
      { lines = { "rename total here", "total = total + 1", "# counter stays" } },
      { cursor = { 1, 7 }, keywords = { "C-r C-w", "C-r C-a", "C-r C-l", "command line" } }
    ),
    a.lesson(
      "cmdline-paste-register",
      "Search for yanked text",
      "Yank `build-cache` and search for it by pasting the register into the search.",
      {
        "With the cursor on `build-cache`, yank the WORD with `yiW`.",
        "Press `/`, then `<C-r>0` to insert the yank, and `<CR>`.",
        '`<C-r>"` inserts the unnamed register and `<C-r>/` the last search pattern. The same keys work after `:`.',
      },
      { "needle: build-cache", "hay stack", "hay build-cache here" },
      { cursor = { 3, 4 }, search_accepts = { "build-cache" }, search_rejects = { "build", "cache" } },
      { cursor = { 1, 8 }, keywords = { "C-r 0", 'C-r "', "C-r /", "search", "register" } }
    ),
    a.lesson(
      "help-tag-jump",
      "Look something up in the help",
      "Open the help for `word-motions`, then return to this window and leave the help open.",
      {
        "Run `:help word-motions`. Help opens in its own window at that tag.",
        "In help, `<C-]>` follows the tag under the cursor and `<C-o>` goes back. `:helpgrep` searches all help files.",
        "Return here with `<C-w>p`, the previous window. `:helpclose` closes the help from anywhere.",
      },
      { "Look it up, then come back." },
      {
        extra = function(context)
          if vim.api.nvim_get_current_buf() ~= context.buf then
            return false
          end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(context.tab)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "help" and vim.api.nvim_buf_get_name(buf):match("motion%.txt$") then
              return true
            end
          end
          return false
        end,
      },
      { keywords = { ":help", "C-]", "C-o", ":helpgrep", ":helpclose", "C-w p" } }
    ),
  },
}
