local a = require("neovim_dojo.author")
local lessons = {
  a.lesson(
    "word-versus-big-word",
    "Word and WORD boundaries",
    "Land on `path` inside the first punctuation-separated filename.",
    {
      "From the start, `w` moves to `name`, then to `-`; another `w` reaches `path`.",
      "Reset with `,r` and compare `W`: it crosses the entire nonblank `name-path.lua` WORD.",
      "Finish with the cursor on the `p` of `path` in the first filename. Punctuation creates word boundaries, spaces create WORD boundaries.",
    },
    { "open name-path.lua next-file.py" },
    { cursor = { 1, 10 } },
    { keywords = { "w", "W", "word", "WORD", "punctuation" } }
  ),
  a.lesson(
    "counted-word-ends",
    "Counted word endings",
    "Reach the last character of the third word without overshooting it.",
    {
      "Compare `3w` with `3e` from the starting position; use `,r` between attempts.",
      "Finish on the `r` of `cedar` using `3e`. `e` includes the current word ending; `w` seeks the next beginning.",
    },
    { "amber birch cedar delta" },
    { cursor = { 1, 16 } },
    { keywords = { "e", "ge", "count", "3e" } }
  ),
  a.lesson(
    "line-and-exact-marks",
    "Line marks and exact marks",
    "Set local mark `a` on `ORIGIN`, move away, then return to that exact column.",
    {
      "On `ORIGIN`, type `ma`, then `G` to leave the line.",
      "Compare `'a` (first nonblank of the marked line) with backtick-a (exact position). Finish with backtick-a.",
      "Local lowercase marks belong to this buffer. The uppercase file marks are a different, persistent mechanism.",
    },
    { "    keep ORIGIN here", "leave this line unchanged", "far destination" },
    {
      -- Setting the mark does not move the cursor, so require the round trip.
      kind = "cursor_round_trip",
      target = { line = 3, text = "far destination" },
      origin = { 1, 9 },
      mark = { name = "a", position = { 1, 9 } },
    },
    { revision = 2, cursor = { 1, 9 }, keywords = { "ma", "'a", "`a", "mark" } }
  ),
  a.lesson(
    "jump-list-change-list",
    "Jump list and change list",
    "Compare navigation history with edit history in this disposable buffer.",
    {
      "Use `G`, `gg`, `<C-o>` and `<C-i>`; inspect `:jumps` to see navigation history.",
      "Change `old` to `new` on the first and third lines in separate edits. Use `g;` and `g,` to visit changes, then inspect `:changes`.",
      "Jumps and changes are different lists. After comparing their destinations, mark this observational lesson with `,m`.",
    },
    { "first old", "unchanged middle", "third old" },
    { kind = "manual" },
    { keywords = { ":jumps", ":changes", "g;", "g,", "C-o", "C-i" } }
  ),
  a.drill(
    "word-boundary-drill",
    "Choose precise word boundaries",
    "Reach exact word starts and endings amid punctuation and spaces.",
    {
      "Read the requested destination; use `w`, `W`, `e`, `b` and counts. Check exact columns with `,k`.",
    },
    {
      {
        goal = "Reach p in path in name-path.lua",
        lines = { "open name-path.lua next-file.py" },
        check = { cursor = { 1, 10 } },
      },
      { goal = "Reach final r in cedar", lines = { "amber birch cedar delta" }, check = { cursor = { 1, 16 } } },
      {
        goal = "Reach n in next-file.py with a WORD motion",
        lines = { "open name-path.lua next-file.py" },
        check = { cursor = { 1, 19 } },
      },
    }
  ),
  a.drill(
    "mark-edit-return-drill",
    "Mark, edit, and return",
    "Keep an exact origin while making a distant edit in three scenes.",
    {
      "Set `ma` at the initial cursor, change only `old` to `new` on the distant line, and return with backtick-a.",
      "The checker requires the mark, the exact return column and all surrounding text.",
    },
    {
      {
        goal = "Mark ORIGIN; change old below to new; return exactly",
        lines = { "keep ORIGIN", "far old" },
        cursor = { 1, 5 },
        check = { lines = { "keep ORIGIN", "far new" }, cursor = { 1, 5 }, mark = { name = "a", position = { 1, 5 } } },
      },
      {
        goal = "Mark ANCHOR; change old above to new; return exactly",
        lines = { "far old", "  keep ANCHOR" },
        cursor = { 2, 7 },
        check = {
          lines = { "far new", "  keep ANCHOR" },
          cursor = { 2, 7 },
          mark = { name = "a", position = { 2, 7 } },
        },
      },
      {
        goal = "Mark HOME; change old on middle row to new; return",
        lines = { "stay HOME", "old", "protected" },
        cursor = { 1, 5 },
        check = {
          lines = { "stay HOME", "new", "protected" },
          cursor = { 1, 5 },
          mark = { name = "a", position = { 1, 5 } },
        },
      },
    }
  ),
  a.lesson(
    "backward-word-motions",
    "Move backward by word",
    "From `delta`, reach the last letter of `beta`.",
    {
      "`b` moves back to the start of a word and `ge` back to the end of the previous word. `B` and `gE` do the same for WORDs.",
      "The cursor is on the `d` of `delta`. `ge` reaches the end of `gamma`; type `2ge` to reach the `a` that ends `beta`.",
      "`2b` would land on the first letter of `beta` instead.",
    },
    { "alpha beta gamma delta" },
    { cursor = { 1, 9 } },
    { cursor = { 1, 17 }, keywords = { "b", "B", "ge", "gE", "2ge", "backward" } }
  ),
  a.lesson(
    "jump-back-previous-position",
    "Jump back to where you were",
    "Jump to the last line, then return to the exact position on `ORIGIN`.",
    {
      "Press `G` to jump to the last line. A jump remembers where it started.",
      "Press backtick twice to return to that exact position. `''` (two single quotes) returns to the line only, at its first non-blank character.",
      "Pressing it again jumps back and forth between the two places. `<C-o>` walks further back through older jumps.",
    },
    { "top", "", "    keep ORIGIN here", "middle", "middle", "middle", "far destination" },
    {
      kind = "cursor_round_trip",
      target = { line = 7, text = "far destination" },
      origin = { 3, 9 },
    },
    { cursor = { 3, 9 }, keywords = { "``", "''", "G", "C-o", "jump" } }
  ),
  a.lesson(
    "revisit-older-change",
    "Return to an earlier change",
    "Change `old` to `new` on the first and on the last line, then return to the first change with the change list.",
    {
      "On the first line change `old` to `new`, for example with `$ciwnew` and `<Esc>`. Do the same on the last line.",
      "Press `g;`. It goes to the position of the latest change, where you already are. Press `g;` again for the change before it.",
      "`g,` goes forward again and `:changes` lists the positions. Finish on the first line, where `g;` puts you.",
    },
    { "first old", "filler a", "filler b", "filler c", "last old" },
    {
      lines = { "first new", "filler a", "filler b", "filler c", "last new" },
      -- The line, not the column: where in a change the list points varies.
      extra = function(context)
        return vim.api.nvim_get_current_buf() == context.buf and vim.api.nvim_win_get_cursor(0)[1] == 1
      end,
    },
    { keywords = { "g;", "g,", ":changes", "change list" } }
  ),
  a.lesson(
    "marks-as-ranges",
    "Operate up to a mark",
    "Delete the three `cut` lines by marking the first and deleting from the last.",
    {
      "On `cut one` set a mark with `ma`.",
      "Move to `cut three` and type `d'a`: delete from this line through the line of mark `a`.",
      "With a backtick instead of the quote, the motion is exact to the character instead of whole lines. `y'a` and `>'a` work the same way.",
    },
    { "keep top", "cut one", "cut two", "cut three", "keep bottom" },
    { lines = { "keep top", "keep bottom" } },
    { keywords = { "ma", "d'a", "y'a", ">'a", "mark", "range" } }
  ),
  a.drill(
    "mark-range-drill",
    "Edit from the cursor to a mark",
    "Set a mark at one end, move to the other, and apply an operator to the lines between.",
    {
      "Use `ma` and then an operator with `'a`. The checker requires the mark where the round says, when the marked line still exists.",
    },
    {
      {
        goal = "Mark line 2; delete lines 2 to 4 from line 4",
        lines = { "a", "b", "c", "d", "e" },
        check = { lines = { "a", "e" } },
      },
      {
        goal = "Mark line 1; uppercase lines 1 to 3 from line 3",
        lines = { "one", "two", "three", "four" },
        check = { lines = { "ONE", "TWO", "THREE", "four" }, mark = { name = "a", position = { 1, 0 } } },
      },
      {
        goal = "Mark line 2; indent lines 2 and 3 once (two spaces)",
        lines = { "a", "b", "c", "d" },
        options = { shiftwidth = 2, expandtab = true },
        check = { lines = { "a", "  b", "  c", "d" }, mark = { name = "a", position = { 2, 0 } } },
      },
    }
  ),
}
return {
  id = "precision-movement",
  title = "Precise Movement",
  description = "Word boundaries, local marks, and navigation versus edit history.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "movement", "history" },
  lessons = lessons,
}
