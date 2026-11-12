local a = require("neovim_dojo.author")
local w = require("neovim_dojo.workspace")
return {
  id = "buffers",
  title = "Buffers",
  description = "Understand, inspect, and switch Neovim's in-memory text objects.",
  topics = { "navigation", "windows" },
  source = { kind = "vim" },
  keywords = { "buffer", ":ls", ":buffers", ":buffer", "hidden", "alternate", "C-^" },
  lessons = {
    {
      id = "inspect-open-buffers",
      revision = 2,
      title = "Inspect open buffers",
      objective = "Inspect listed buffers and recognize the current, alternate, visible, hidden, and modified markers.",
      steps = {
        "Run `:ls` or `:buffers`. Find `%` for the current buffer, `#` for the alternate buffer, `a` for visible, `h` for hidden, and `+` for modified.",
        "Use `:ls!` to include unlisted buffers too; the `!` does not mean hidden. A hidden buffer simply has no window displaying it.",
        "Remember the model: a buffer owns text, a window displays a buffer, and a tab page owns a window layout.",
        "Press `,m` when those three objects and the list markers make sense.",
      },
      hint = "`:ls` shows listed buffers, visible or hidden. `:ls!` adds unlisted buffers.",
      filetype = "text",
      lines = {
        "CURRENT · this task buffer is displayed in the window",
        "The setup also created two listed buffers that are currently hidden.",
      },
      cursor = { 1, 0 },
      setup = {
        kind = "buffer_navigation",
        buffers = {
          { name = "buffer-reference", lines = { "REFERENCE · a hidden listed buffer" } },
          { name = "buffer-notes", lines = { "NOTES · another hidden listed buffer" } },
        },
      },
      check = { kind = "manual" },
    },
    {
      id = "switch-hidden-buffer",
      revision = 2,
      title = "Switch to a hidden buffer",
      objective = "Use the native buffer list and `:buffer` to display a hidden buffer in the current window.",
      steps = {
        "Run `:ls` and find the number of the hidden temporary `buffer-target.txt` file.",
        "Run `:buffer {number}`, replacing `{number}` with that buffer number.",
        "Notice that the window remains; only the buffer displayed inside it changes.",
      },
      hint = "`:buffer buffer-target` also works when that text uniquely identifies the buffer name.",
      filetype = "text",
      lines = { "CURRENT · replace the contents of this window by switching buffers" },
      cursor = { 1, 0 },
      setup = {
        kind = "buffer_navigation",
        buffers = {
          { name = "buffer-target", target = true, lines = { "TARGET · hidden buffer reached" } },
        },
      },
      check = { kind = "target_buffer" },
    },
    {
      id = "switch-alternate-buffer",
      revision = 2,
      title = "Switch to the alternate buffer",
      objective = "Jump from the current buffer to the previous buffer with `<C-^>`.",
      steps = {
        "Run `:ls` and find the buffer marked `#`; the setup made it the alternate buffer.",
        "Press `<C-^>` to display that buffer in the current window.",
        "Pressing `<C-^>` again toggles back, which is useful when moving repeatedly between two files.",
      },
      hint = "The alternate buffer belongs to the current window and is also available as `:buffer #` or `:edit #`.",
      filetype = "text",
      lines = { "CURRENT · press Ctrl-^ to revisit the alternate buffer" },
      cursor = { 1, 0 },
      setup = {
        kind = "buffer_navigation",
        prime_alternate = true,
        buffers = {
          { name = "buffer-alternate", target = true, lines = { "ALTERNATE · previous buffer reached" } },
        },
      },
      check = { kind = "target_buffer" },
    },
    a.lesson("cycle-listed-buffers", "Step through the buffer list", "Show the next listed buffer in this window.", {
      "Run `:bnext`. The window shows the next buffer of the list, the hidden `buffer-next.txt`.",
      "`:bprevious` goes back, and `:bfirst` and `:blast` go to the ends. Neovim 0.11 and later also map `]b` and `[b`.",
      "Stepping suits a short list. For a long one, `:buffer` with part of a name is faster.",
    }, { "CURRENT · step to the next buffer in the list" }, { kind = "target_buffer" }, {
      setup = {
        kind = "buffer_navigation",
        buffers = { { name = "buffer-next", target = true, lines = { "NEXT · reached with :bnext" } } },
      },
      keywords = { ":bnext", ":bprevious", ":bfirst", ":blast", "]b", "[b" },
    }),
    a.lesson(
      "delete-hidden-buffer",
      "Remove a buffer from the list",
      "Delete the hidden buffer `buffer-scrap.txt` without changing this window.",
      {
        "Run `:ls` and find the hidden `buffer-scrap.txt`.",
        "Run `:bdelete` with its number, or `:bdelete buffer-scrap`. The buffer leaves the list; the file on disk is untouched.",
        "`:bdelete` without an argument deletes the current buffer and closes its windows. `:bwipeout` also forgets marks and options.",
      },
      { "CURRENT · this window stays as it is" },
      {
        extra = function(context)
          local scrap = context.target_buffer
          return scrap ~= nil and not (vim.api.nvim_buf_is_valid(scrap) and vim.bo[scrap].buflisted)
        end,
        cursor = { 1, 0 },
      },
      {
        setup = {
          kind = "buffer_navigation",
          buffers = { { name = "buffer-scrap", target = true, lines = { "SCRAP · no longer needed" } } },
        },
        keywords = { ":bdelete", ":bd", ":bwipeout", ":ls" },
      }
    ),
    w.lesson(
      "save-all-buffers",
      "Save every changed buffer",
      "Append ` saved` to the first line of `main.txt` and of `alpha.txt`, then write both with one command.",
      {
        "Append ` saved` here. Open the other file with `:edit alpha.txt` and append the same there; the changed `main.txt` stays loaded and hidden.",
        "Run `:wall` (`:wa`). It writes every changed buffer.",
        "`:update` writes the current buffer only if it changed, and `:xall` writes everything and quits.",
      },
      { "notes" },
      {
        disk = true,
        files = { ["main.txt"] = { "notes saved" }, ["alpha.txt"] = { "alpha reference saved" } },
      },
      { files = { ["alpha.txt"] = { "alpha reference" } } },
      { keywords = { ":wall", ":wa", ":update", ":xall", "save" } }
    ),
    w.lesson(
      "discard-unsaved-changes",
      "Throw away unsaved changes",
      "Damage this file on purpose, then get the saved version back.",
      {
        "Delete a line, for example with `dd`. The buffer is now modified.",
        "Run `:edit!`. It reads the file from disk again and discards every unsaved change.",
        "This also reloads a file that another program changed. Undo with `u` reaches the same text here, but not after a restart without undo history.",
      },
      { "keep this line", "and this one" },
      {
        -- The text alone is the starting state: the buffer must have been
        -- modified in between. `extra` sees every check, so it can remember.
        extra = function(context)
          local workspace = context.workspace
          local modified = vim.bo[context.buf].modified
          workspace.was_modified = workspace.was_modified or modified
          return workspace.was_modified
            and not modified
            and vim.deep_equal(w.lines(context, "main.txt"), { "keep this line", "and this one" })
        end,
      },
      {},
      { keywords = { ":edit!", ":e!", "discard", "reload" } }
    ),
  },
}
