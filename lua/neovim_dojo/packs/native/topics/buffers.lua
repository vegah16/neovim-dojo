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
  },
}
