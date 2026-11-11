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
