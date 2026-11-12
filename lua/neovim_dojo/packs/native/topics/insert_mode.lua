local a = require("neovim_dojo.author")
return {
  id = "insert-mode",
  title = "Insert Mode",
  description = "Enter Insert mode in the right place, and fix and paste without leaving it.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "text-editing" },
  lessons = {
    a.lesson(
      "insert-entry-points",
      "Enter Insert mode in the right place",
      "Add `local ` in front of the first line, `;` at its end, and a new line `log value` below it.",
      {
        "`I` inserts before the first non-blank character and `A` appends at the end of the line, wherever the cursor is.",
        "Type `Ilocal `, press `<Esc>`, then `A;` and `<Esc>`.",
        "`o` opens a new line below and `O` one above. Type `olog value` and press `<Esc>`.",
      },
      { "value = 10", "return value" },
      { lines = { "local value = 10;", "log value", "return value" } },
      { cursor = { 1, 6 }, keywords = { "i", "a", "I", "A", "o", "O" } }
    ),
    a.lesson(
      "insert-with-count",
      "Repeat an insert with a count",
      "Turn the empty second line into a rule of twenty dashes.",
      {
        "A count before an insert command repeats the typed text when you leave Insert mode.",
        "On the empty line type `20i-` and press `<Esc>`.",
        "The same works with `a`, `A`, `I` and `o`: `3Ago <Esc>` appends `go go go `.",
      },
      { "Release notes", "", "body" },
      { lines = { "Release notes", "--------------------", "body" } },
      { cursor = { 2, 0 }, keywords = { "20i-", "count", "insert" } }
    ),
    a.lesson(
      "insert-delete-word-line",
      "Fix a typo without leaving Insert mode",
      "Finish the line as `status: ready`, correcting a typo with `<C-w>`.",
      {
        "Press `A` and type the typo `redy`.",
        "Press `<C-w>` to delete the word before the cursor, then type `ready` and press `<Esc>`.",
        "`<C-u>` deletes everything you typed on the line. Both keys also work on the command line.",
      },
      { "status: ", "protected" },
      { lines = { "status: ready", "protected" } },
      { keywords = { "C-w", "C-u", "insert", "typo" } }
    ),
    a.lesson(
      "insert-paste-register",
      "Paste a register while typing",
      "Yank `harbor-light` and paste it after `copy: ` from Insert mode.",
      {
        "With the cursor on `harbor-light`, yank the WORD with `yiW`.",
        "Go to the second line, press `A`, then `<C-r>0` to insert register `0`, the last yank. Press `<Esc>`.",
        '`<C-r>"` inserts the unnamed register and `<C-r>a` register `a`. The same keys work on the command line.',
      },
      { "source: harbor-light", "copy: " },
      { lines = { "source: harbor-light", "copy: harbor-light" } },
      { cursor = { 1, 8 }, keywords = { "C-r", "register", "insert", "paste" } }
    ),
    a.lesson(
      "insert-indent-keys",
      "Indent from Insert mode",
      "Give both inner lines two spaces of indent without leaving Insert mode for the indent.",
      {
        "In Insert mode `<C-t>` adds one 'shiftwidth' of indent to the line and `<C-d>` removes one, wherever the cursor is.",
        "On `run()` press `I`, then `<C-t>`, then `<Esc>`.",
        "On `stop()` press `I`, then `<C-d>` twice: from six spaces to two. Press `<Esc>`.",
      },
      { "if ready then", "run()", "      stop()", "end" },
      { lines = { "if ready then", "  run()", "  stop()", "end" } },
      { options = { shiftwidth = 2, expandtab = true }, keywords = { "C-t", "C-d", "indent", "shiftwidth" } }
    ),
    a.lesson(
      "insert-special-character",
      "Insert a character by its code",
      "Finish the word as `café`.",
      {
        "Press `A`, then `<C-v>u00e9`: `<C-v>` followed by `u` and four hexadecimal digits inserts that Unicode character.",
        "Press `<Esc>`. `ga` on a character shows its code.",
        "Common characters also have two-key digraphs: `<C-k>e'` gives the same letter, and `:digraphs` lists them all.",
      },
      { "caf", "protected" },
      { lines = { "café", "protected" } },
      { keywords = { "C-v", "C-k", "digraph", "unicode", "ga" } }
    ),
    a.lesson(
      "replace-mode-overtype",
      "Overtype with Replace mode",
      "Change the version to `2.0.0` by typing over it.",
      {
        "The cursor is on the `1`. Press `R` to enter Replace mode: every key replaces the character under the cursor.",
        "Type `2.0.0` and press `<Esc>`.",
        "In Replace mode `<BS>` brings the old character back. For one character, `r{char}` does it without a mode.",
      },
      { "version = 1.4.2", "keep" },
      { lines = { "version = 2.0.0", "keep" } },
      { cursor = { 1, 10 }, keywords = { "R", "r", "replace", "overtype" } }
    ),
    a.drill(
      "insert-entry-drill",
      "Choose the insert command",
      "Make each edit with the insert command that needs no extra movement.",
      {
        "Use `I`, `A`, `o`, `O` or a count. The text is checked, not the keys.",
      },
      {
        {
          goal = "Add a dash and a space in front of the line",
          lines = { "buy milk", "protected" },
          cursor = { 1, 4 },
          check = { lines = { "- buy milk", "protected" } },
        },
        {
          goal = "Append a space and done to the line",
          lines = { "task one", "protected" },
          check = { lines = { "task one done", "protected" } },
        },
        {
          goal = "Add the line middle between the two lines",
          lines = { "first", "last" },
          check = { lines = { "first", "middle", "last" } },
        },
        {
          goal = "Add the line title above the first line",
          lines = { "body" },
          check = { lines = { "title", "body" } },
        },
        {
          goal = "Make the empty line a row of ten equals signs",
          lines = { "Heading", "" },
          cursor = { 2, 0 },
          check = { lines = { "Heading", "==========" } },
        },
      }
    ),
  },
}
