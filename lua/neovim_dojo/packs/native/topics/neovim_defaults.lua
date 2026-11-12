local a = require("neovim_dojo.author")
return {
  id = "neovim-defaults",
  title = "Comments and Blank Lines",
  description = "Neovim's built-in commenting and its bracket mappings for blank lines.",
  source = { kind = "neovim" },
  bindings = { origin = "native" },
  topics = { "text-editing" },
  lessons = {
    a.lesson(
      "toggle-comment-line",
      "Comment a line out and in",
      "Comment out the `print` line.",
      {
        "Press `gcc` on the line. Neovim adds the comment marker of the file type, here `--` for Lua.",
        "`gcc` on a commented line removes the marker again. A count works: `3gcc`.",
      },
      { "local debug = true", "print(debug)", "return debug" },
      { lines = { "local debug = true", "-- print(debug)", "return debug" } },
      { cursor = { 2, 0 }, filetype = "lua", keywords = { "gcc", "comment", "toggle" } }
    ),
    a.lesson(
      "comment-motion-visual",
      "Comment several lines",
      "Comment out the three `local` lines with one command.",
      {
        "`gc` is an operator. On the first line type `gc2j`: this line and the two below it.",
        "It takes any motion or text object, such as `gcip` for a paragraph, and works on a Visual selection.",
      },
      { "local a = 1", "local b = 2", "local c = 3", "return a" },
      { lines = { "-- local a = 1", "-- local b = 2", "-- local c = 3", "return a" } },
      { filetype = "lua", keywords = { "gc", "gc2j", "gcip", "comment", "operator" } }
    ),
    a.lesson(
      "comment-text-object",
      "A comment block as a text object",
      "Delete the two-line comment block with one command.",
      {
        "After an operator, `gc` is also a text object: the comment lines around the cursor.",
        "On one of the comment lines type `dgc`.",
        "`gcgc` uncomments the whole block instead of deleting it.",
      },
      { "-- stale one", "-- stale two", "local keep = 1" },
      { lines = { "local keep = 1" } },
      { filetype = "lua", keywords = { "dgc", "gcgc", "comment", "text object" } }
    ),
    a.lesson(
      "blank-lines-around",
      "Add blank lines without leaving Normal mode",
      "Put an empty line above and below `second`, with the cursor still on `second`.",
      {
        "Press `[<Space>` to add an empty line above the cursor line, and `]<Space>` to add one below.",
        "The cursor stays where it was, and a count adds several. These two mappings exist in Neovim 0.11 and later.",
      },
      { "first", "second" },
      { lines = { "first", "", "second", "" }, cursor = { 3, 0 } },
      { cursor = { 2, 0 }, keywords = { "[<Space>", "]<Space>", "blank line" } }
    ),
    a.drill("comment-toggle-drill", "Toggle comments", "Comment, uncomment and delete comment lines in Lua.", {
      "Use `gcc`, `gc` with a motion, and `gc` as a text object after `d`.",
    }, {
      {
        goal = "Comment out the middle line",
        lines = { "a = 1", "b = 2", "c = 3" },
        cursor = { 2, 0 },
        check = { lines = { "a = 1", "-- b = 2", "c = 3" } },
      },
      {
        goal = "Uncomment the first two lines",
        lines = { "-- x = 1", "-- y = 2", "z = 3" },
        check = { lines = { "x = 1", "y = 2", "z = 3" } },
      },
      {
        goal = "Delete the whole comment block",
        lines = { "-- old", "-- older", "keep()" },
        check = { lines = { "keep()" } },
      },
      {
        goal = "Comment out all three lines",
        lines = { "p()", "q()", "r()" },
        check = { lines = { "-- p()", "-- q()", "-- r()" } },
      },
    }, { filetype = "lua" }),
  },
}
