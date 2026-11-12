local a = require("neovim_dojo.author")

local padded = "    total = compute(alpha, beta)    "
local nested = "call(outer(inner(alpha), beta), omega) -- done"
local long = {}
for index = 1, 60 do
  long[index] = ("step %02d of a long procedure"):format(index)
end
long[40] = "step 40 · bring this line to the top"
local numbered = {}
for index = 1, 12 do
  numbered[index] = ("entry %02d"):format(index)
end
numbered[9] = "entry 09 · TARGET"
local inner_table = "  retry = { count = 3, delay = wait(base, factor) },"

return {
  id = "motions",
  title = "Line and Screen Motions",
  description = "Reach line ends, numbered lines, paragraphs, brackets and characters with one motion.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "movement" },
  lessons = {
    a.lesson(
      "line-start-end-motions",
      "Line starts and line ends",
      "Reach the last non-blank character of the line, the closing `)`.",
      {
        "`0` goes to column one and `^` to the first non-blank character. Try both.",
        "`$` goes to the very end, here a trailing space. `g_` stops on the last non-blank character.",
        "Finish on the `)` with `g_`. The line keeps its leading and trailing spaces.",
      },
      { padded },
      { cursor = { 1, #vim.trim(padded) + 3 }, lines = { padded } },
      { cursor = { 1, 12 }, keywords = { "0", "^", "$", "g_" } }
    ),
    a.lesson("goto-line-number", "Go to a line by number", "Reach line 9, the entry marked `TARGET`.", {
      "Type `9G`. A count before `G` is a line number; `gg` takes one too, and `:9` does the same from the command line.",
      "Without a count, `G` goes to the last line and `gg` to the first.",
    }, numbered, { cursor = { 9, 0 } }, { keywords = { "G", "gg", "9G", ":9", "line number" } }),
    a.lesson(
      "paragraph-motions",
      "Move by paragraph",
      "Reach the blank line after the second paragraph.",
      {
        "`}` moves forward to the next blank line and `{` moves back. A paragraph ends at a blank line.",
        "From the first line, `2}` reaches the blank line after the second paragraph.",
        "These motions work after an operator too: `d}` deletes to the end of the paragraph.",
      },
      { "first one", "first two", "", "second one", "second two", "", "third one", "third two" },
      { cursor = { 6, 0 } },
      { keywords = { "{", "}", "paragraph", "2}" } }
    ),
    a.lesson(
      "matching-pair-percent",
      "Jump to the matching bracket",
      "From the `(` after `outer`, reach the `)` that closes it.",
      {
        "The cursor starts on the `(` after `outer`. Press `%` to jump to its partner.",
        "`%` works on `()`, `[]` and `{}`, and from anywhere before a bracket on the line. Press it again to jump back.",
        "As a motion it takes operators: `d%` deletes the whole bracketed group.",
      },
      { nested },
      { cursor = { 1, nested:find(", omega", 1, true) - 2 } },
      { cursor = { 1, nested:find("(inner", 1, true) - 1 }, keywords = { "%", "matching", "bracket" } }
    ),
    a.lesson(
      "find-till-character",
      "Find and till a character",
      "Delete the first two arguments, so that the call reads `copy(mode, flags)`.",
      {
        "`f{char}` moves onto the next `{char}` on the line; `t{char}` stops just before it. `F` and `T` look backward, and `;` repeats the last one.",
        "Move to `src` with `fs`, then delete with `dtm`: up to, but not including, the `m` of `mode`.",
        "`df` would take the target character too. Use `,r` to reset and compare.",
      },
      { "copy(src, dst, mode, flags)" },
      { lines = { "copy(mode, flags)" } },
      { keywords = { "f", "t", "F", "T", ";", "dt", "df" } }
    ),
    a.lesson(
      "enclosing-bracket-jumps",
      "Jump to the enclosing bracket",
      "From inside `wait(...)`, reach the `{` that opens the `retry` table.",
      {
        "`[(` jumps back to the unmatched `(` around the cursor and `[{` to the unmatched `{`. `])` and `]}` go forward to the closing ones.",
        "The cursor starts in `factor`. `[(` stops at the `(` of `wait`; `[{` skips it and reaches the `{` after `retry =`.",
        "Finish on that `{`.",
      },
      { "config = {", inner_table, "}" },
      { cursor = { 2, inner_table:find("{", 1, true) - 1 } },
      { cursor = { 2, inner_table:find("factor", 1, true) + 1 }, keywords = { "[(", "[{", "])", "]}" } }
    ),
    a.lesson(
      "position-line-in-window",
      "Place the cursor line in the window",
      "Go to line 40 and scroll it to the top of the window.",
      {
        "Type `40G`. Neovim shows the line somewhere in the middle of the window.",
        "Press `zt` to put the cursor line at the top, `zz` in the middle, or `zb` at the bottom. The cursor stays on its line; only the view moves.",
        "Finish with `zt` on line 40. With 'scrolloff' set, a few lines of context stay above it.",
      },
      long,
      { cursor = { 40, 0 }, winline = "top" },
      { keywords = { "zt", "zz", "zb", "scroll", "scrolloff" } }
    ),
    a.drill("line-motion-drill", "Reach lines, ends and brackets", "Reach each requested position with one motion.", {
      "Use `^`, `g_`, a count with `G`, `}` and `%`. The cursor position is checked exactly.",
    }, {
      {
        goal = "Reach the last non-blank character",
        lines = { "  alpha beta gamma   " },
        cursor = { 1, 4 },
        check = { cursor = { 1, 17 } },
      },
      {
        goal = "Reach line 7",
        lines = { "row 1", "row 2", "row 3", "row 4", "row 5", "row 6", "row 7", "row 8", "row 9" },
        check = { cursor = { 7, 0 } },
      },
      {
        goal = "Reach the bracket that closes run(",
        lines = { "run(pick(a, b), c) + tail" },
        cursor = { 1, 3 },
        check = { cursor = { 1, 17 } },
      },
      {
        goal = "Reach the blank line after the first paragraph",
        lines = { "one", "two", "", "three", "four", "", "five" },
        check = { cursor = { 3, 0 } },
      },
      {
        goal = "Reach the first non-blank character",
        lines = { "      indented target line" },
        cursor = { 1, 20 },
        check = { cursor = { 1, 6 } },
      },
    }),
    a.drill(
      "find-till-drill",
      "Edit up to a character",
      "Combine an operator with `f` or `t` to edit exactly up to a character.",
      {
        "`f` includes the character and `t` stops before it. A count picks a later occurrence.",
      },
      {
        {
          goal = "Delete through the first colon",
          lines = { "prefix: keep this", "protected" },
          check = { lines = { " keep this", "protected" } },
        },
        {
          goal = "Delete up to, not including, the equals sign",
          lines = { "stale_name = value", "protected" },
          check = { lines = { "= value", "protected" } },
        },
        {
          goal = "Change the text before the closing bracket to x",
          lines = { "items[old_index]", "protected" },
          cursor = { 1, 6 },
          check = { lines = { "items[x]", "protected" } },
        },
        {
          goal = "Delete through the second slash",
          lines = { "usr/local/share/doc", "protected" },
          check = { lines = { "share/doc", "protected" } },
        },
      }
    ),
  },
}
