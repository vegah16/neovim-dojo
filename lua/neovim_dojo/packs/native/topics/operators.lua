local a = require("neovim_dojo.author")
return {
  id = "operators",
  title = "Operators and Repeat",
  description = "Compose edits and repeat useful changes without disturbing their surroundings.",
  source = { kind = "vim" },
  topics = { "text-editing" },
  lessons = {
    a.lesson(
      "compose-operator-motion",
      "Compose operator and motion",
      "Remove the two obsolete words while keeping the final word and second line.",
      {
        "At `obsolete`, use `d2w`: delete applied to two word motions.",
        "`c` would enter Insert mode for replacement; `y` would copy the same motion without removing text.",
      },
      { "obsolete stale keep", "protected" },
      { lines = { "keep", "protected" } },
      { keywords = { "d2w", "operator", "motion", "c", "y" } }
    ),
    a.lesson(
      "operator-count-placement",
      "Counts before and after an operator",
      "Delete six words with a composed count, preserving `keep`.",
      {
        "Use `2d3w` or `d6w` from the start. Counts multiply: two operations of three words.",
        "Reset and compare both forms. Avoid a linewise deletion that would also remove `keep`.",
      },
      { "one two three four five six keep", "protected" },
      { lines = { "keep", "protected" } },
      { keywords = { "2d3w", "d6w", "count" } }
    ),
    a.lesson(
      "dot-repeat-separated-edits",
      "Repeat a change with dot",
      "Change both `old` values to `ready`, preserving the middle line.",
      {
        "Use `ciwready<Esc>` on the first `old`, move to the second `old`, then press `.`.",
        "Dot repeats the last edit, including the inserted text; motions between edits do not replace it.",
      },
      { "old", "keep", "old" },
      { lines = { "ready", "keep", "ready" }, repeat_contains = "ready" },
      { keywords = { ".", "ciw", "repeat" } }
    ),
    a.lesson(
      "join-and-reindent",
      "Join and reindent a region",
      "Join the two argument lines, then reindent the Lua block.",
      {
        "Use `J` on the call line to join it to the next argument line with whitespace handling.",
        "Use `gg=G` to reindent the block. `=` plus a motion reindents a region; `==` reindents one line.",
        "The call must be indented two spaces. Keep the comment intact. After reset, compare `J` with `gJ`: `gJ` adds no joining space.",
      },
      { "if ready then", "print(alpha,", " beta)", "end", "-- protected" },
      { lines = { "if ready then", "  print(alpha, beta)", "end", "-- protected" } },
      {
        cursor = { 2, 0 },
        filetype = "lua",
        -- The expected result is two-space indentation, whatever the user's own.
        options = { shiftwidth = 2, expandtab = true },
        keywords = { "J", "gJ", "=", "==" },
      }
    ),
    a.drill(
      "operator-repair-drill",
      "Repair with composed operators",
      "Apply deletion and change motions to distinct text structures.",
      {
        "Remove only the obsolete text or replace the requested interior; keep punctuation and protected lines.",
      },
      {
        {
          goal = "Delete the first two words",
          lines = { "remove stale keep", "protected" },
          check = { lines = { "keep", "protected" } },
        },
        {
          goal = "Change only the contents of quotes to ready",
          lines = { 'value = "old words"', "protected" },
          cursor = { 1, 9 },
          check = { lines = { 'value = "ready"', "protected" } },
        },
        {
          goal = "Delete from old through end of line",
          lines = { "keep old trailing", "protected" },
          cursor = { 1, 5 },
          check = { lines = { "keep ", "protected" } },
        },
      }
    ),
    a.drill(
      "repeat-correction-drill",
      "Repeat separated corrections",
      "Apply one repeatable correction across separated targets, preserving decoys.",
      {
        "Change the first target, use motions to find the next, and repeat with `.`. The checker sees the final text and inserted change, not proof of every dot press.",
      },
      {
        {
          goal = "Change both old to ready; preserve oldish",
          lines = { "old", "oldish", "old" },
          check = { lines = { "ready", "oldish", "ready" }, repeat_contains = "ready" },
        },
        {
          goal = "Change both draft to done; preserve drafting",
          lines = { "draft", "drafting", "draft" },
          check = { lines = { "done", "drafting", "done" }, repeat_contains = "done" },
        },
        {
          goal = "Change both wait to go; preserve waiting",
          lines = { "wait", "waiting", "wait" },
          check = { lines = { "go", "waiting", "go" }, repeat_contains = "go" },
        },
      }
    ),
    a.lesson(
      "case-operators",
      "Change case with an operator",
      "Uppercase the word `release` and lowercase the whole second line.",
      {
        "`gU` uppercases, `gu` lowercases and `g~` toggles what a motion or text object covers.",
        "On `release` type `gUiw`. On the second line type `guu`: doubling the last letter applies an operator to the line.",
        "In Visual mode the same operators are `U`, `u` and `~`.",
      },
      { "title: release notes", "SHOUTING LINE", "protected" },
      { lines = { "title: RELEASE notes", "shouting line", "protected" } },
      { cursor = { 1, 7 }, keywords = { "gU", "gu", "g~", "gUiw", "guu", "g~~", "case" } }
    ),
    a.lesson(
      "indent-operators",
      "Shift lines with an operator",
      "Indent the two lines inside the block, and remove the indent of the last line.",
      {
        "`>` and `<` shift lines by one 'shiftwidth'. `>>` shifts the current line and `>j` this line and the next.",
        "On `run()` type `>j`.",
        "On `stray()` type `<<` and repeat it with `.` until the indent is gone.",
      },
      { "if ready then", "run()", "stop()", "end", "    stray()" },
      { lines = { "if ready then", "  run()", "  stop()", "end", "stray()" } },
      { options = { shiftwidth = 2, expandtab = true }, keywords = { ">", "<", ">>", "<<", ">j", "indent" } }
    ),
    a.lesson(
      "change-delete-to-line-end",
      "Change or delete to the end of the line",
      "Replace the rest of the first line with `done`, and cut the comment off the second.",
      {
        "`C` changes from the cursor to the end of the line, like `c$`. The cursor is on `compute`: type `Cdone` and press `<Esc>`.",
        "`D` deletes to the end of the line, like `d$`. On the second line move to the space before `#` and press `D`.",
        "Their whole-line relatives are `cc` (or `S`) and `dd`.",
      },
      { "result = compute(old, args)", "limit = 10 # remove this" },
      { lines = { "result = done", "limit = 10" } },
      { cursor = { 1, 9 }, keywords = { "C", "D", "c$", "d$", "cc", "dd" } }
    ),
    a.lesson(
      "swap-characters-lines",
      "Swap two characters or two lines",
      "Fix `teh` to `the`, and swap the two lines below it.",
      {
        "A delete followed by a put moves text. The cursor is on the `e` of `teh`: `xp` cuts it and puts it after the next character.",
        "On the line `second`, `ddp` cuts the line and puts it below the next one.",
        "`ddP` moves a line up instead, and `yyp` duplicates one.",
      },
      { "teh quick fox", "second", "first" },
      { lines = { "the quick fox", "first", "second" } },
      { cursor = { 1, 1 }, keywords = { "xp", "ddp", "ddP", "yyp", "swap" } }
    ),
    a.lesson(
      "increment-numbers",
      "Add to and subtract from a number",
      "Make the three values 4, 25 and 8090.",
      {
        "`<C-a>` adds one to the number under or after the cursor and `<C-x>` subtracts one. The cursor need not be on the number.",
        "Press `<C-a>` on the first line. On the second type `5<C-x>`, and on the third `10<C-a>`.",
        "A count is the amount. The change repeats with `.`.",
      },
      { "retries = 3", "timeout = 30", "port = 8080" },
      { lines = { "retries = 4", "timeout = 25", "port = 8090" } },
      { keywords = { "C-a", "C-x", "increment", "decrement", "number" } }
    ),
    a.lesson(
      "increment-sequence",
      "Number lines with a growing increment",
      "Turn the four `0.` prefixes into `1.` to `4.`.",
      {
        "Select all four lines with `VG`.",
        "Type `g<C-a>`: the first selected number grows by one, the second by two, and so on.",
        "A plain `<C-a>` on the selection would add one to every line. A count is the step: `2g<C-a>` gives 2, 4, 6.",
      },
      { "0. alpha", "0. beta", "0. gamma", "0. delta" },
      { lines = { "1. alpha", "2. beta", "3. gamma", "4. delta" } },
      { keywords = { "g<C-a>", "g C-a", "sequence", "numbering" } }
    ),
    a.lesson(
      "format-paragraph",
      "Rewrap a paragraph",
      "Rewrap the long first paragraph to the width of 30 columns that this task sets.",
      {
        "`gq` formats what a motion or text object covers to 'textwidth'. Type `gqap` on the long line.",
        "`gqq` formats one line. `gw` does the same and leaves the cursor where it was.",
        "The second paragraph is short enough and stays as it is.",
      },
      { "This sentence is far too long to sit on one line of a narrow note.", "", "Short line stays." },
      {
        lines = {
          "This sentence is far too long",
          "to sit on one line of a narrow",
          "note.",
          "",
          "Short line stays.",
        },
      },
      { options = { textwidth = 30, formatoptions = "tcq" }, keywords = { "gq", "gqap", "gqq", "gw", "textwidth" } }
    ),
    a.lesson(
      "replace-characters",
      "Replace characters in place",
      "Mask the last four digits with `*`.",
      {
        "`r{char}` replaces the character under the cursor and stays in Normal mode.",
        "With a count it replaces that many characters. The cursor is on the first of the four digits: type `4r*`.",
        "`r<CR>` splits the line at the cursor.",
      },
      { "id = 4821-7733", "protected" },
      { lines = { "id = 4821-****", "protected" } },
      { cursor = { 1, 10 }, keywords = { "r", "4r*", "replace" } }
    ),
    a.drill(
      "case-indent-drill",
      "Change case and indent",
      "Apply a case or indent operator to exactly the requested text.",
      {
        "Use `gU`, `gu`, `g~`, `>` and `<` with a text object, a motion, or doubled for the line.",
      },
      {
        {
          goal = "Uppercase the word under the cursor",
          lines = { "make this loud", "protected" },
          cursor = { 1, 5 },
          check = { lines = { "make THIS loud", "protected" } },
        },
        {
          goal = "Lowercase the whole first line",
          lines = { "QUIET PLEASE", "Protected" },
          check = { lines = { "quiet please", "Protected" } },
        },
        {
          goal = "Indent the two middle lines once (two spaces)",
          lines = { "do", "a", "b", "end" },
          cursor = { 2, 0 },
          options = { shiftwidth = 2, expandtab = true },
          check = { lines = { "do", "  a", "  b", "end" } },
        },
        {
          goal = "Toggle the case of the whole first line",
          lines = { "mIXED cASE", "Protected" },
          check = { lines = { "Mixed Case", "Protected" } },
        },
      }
    ),
    a.drill(
      "number-adjust-drill",
      "Adjust numbers",
      "Change numbers with `<C-a>`, `<C-x>` and `g<C-a>` instead of retyping them.",
      {
        "A count is the amount to add or subtract. `g<C-a>` on a Visual selection makes a sequence.",
      },
      {
        {
          goal = "Raise the number by one",
          lines = { "level = 9", "protected" },
          check = { lines = { "level = 10", "protected" } },
        },
        {
          goal = "Lower the number by 20",
          lines = { "width = 100", "protected" },
          check = { lines = { "width = 80", "protected" } },
        },
        {
          goal = "Number the rows 1 to 3",
          lines = { "0) a", "0) b", "0) c" },
          check = { lines = { "1) a", "2) b", "3) c" } },
        },
        {
          goal = "Raise both numbers on the first line by one",
          lines = { "x = 1, y = 5", "protected" },
          check = { lines = { "x = 2, y = 6", "protected" } },
        },
      }
    ),
  },
}
