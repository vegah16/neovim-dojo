local a = require("neovim_dojo.author")
return {
  id = "visual-editing",
  title = "Visual and Block Editing",
  description = "Choose, recover and edit precise selections across uneven lines.",
  source = { kind = "vim" },
  topics = { "text-editing", "selection" },
  lessons = {
    a.lesson(
      "visual-selection-kinds",
      "Choose a selection kind",
      "Remove the complete middle line with a linewise selection.",
      {
        "`v` selects characters, `V` selects lines, and `<C-v>` selects a rectangle.",
        "On `remove this line`, press `Vd`. Keep both neighboring lines exactly intact.",
      },
      { "keep before", "remove this line", "keep after" },
      { lines = { "keep before", "keep after" } },
      { cursor = { 2, 4 }, keywords = { "v", "V", "C-v" } }
    ),
    a.lesson(
      "visual-ends-and-reselect",
      "Switch ends and reselect",
      "Uppercase exactly `amber birch` without changing the trailing word.",
      {
        "Select `amber` with `viw`, use `o` to switch the active end, and `o` again to return.",
        "Extend to the end of `birch` with `e`, then press `U`. `gv` restores your previous visual selection if you leave it accidentally.",
        "Finish with `AMBER BIRCH cedar`; the checker checks the output, not which selection recovery you used.",
      },
      { "amber birch cedar" },
      { lines = { "AMBER BIRCH cedar" } },
      { keywords = { "o", "gv", "visual", "U" } }
    ),
    a.lesson(
      "block-insert-column",
      "Insert a repeated column",
      "Prefix all three lines with `# ` using block Insert.",
      {
        "At column zero, press `<C-v>jjI# <Esc>` and wait for Normal mode: the inserted text is repeated on the other selected lines.",
        "The short middle line is intentional. Block mode uses columns rather than matching words.",
      },
      { "alpha", "b", "  gamma" },
      { lines = { "# alpha", "# b", "#   gamma" } },
      { keywords = { "C-v", "I", "block", "column" } }
    ),
    a.lesson(
      "block-delete-rectangle",
      "Delete a rectangle",
      "Delete the two-character status column without altering the following fields.",
      {
        "At column zero use `<C-v>jjld` to select two columns across three rows and delete them.",
        "A rectangular selection can cross different words and indentation. Compare its edges before applying an operator.",
      },
      { "x alpha", "y b", "z   gamma" },
      { lines = { "alpha", "b", "  gamma" } },
      { keywords = { "C-v", "rectangle", "d" } }
    ),
    a.drill(
      "column-patch-drill",
      "Patch repeated columns",
      "Insert or delete a column across short and indented rows.",
      {
        "Use block `I` for insertion or block `d` for deletion. Preserve all content outside the requested rectangle.",
      },
      {
        {
          goal = "Prefix each row with # and a space",
          lines = { "alpha", "b", "  gamma" },
          check = { lines = { "# alpha", "# b", "#   gamma" } },
        },
        {
          goal = "Remove the two-character prefix on each row",
          lines = { "x one", "y z", "z   three" },
          check = { lines = { "one", "z", "  three" } },
        },
        {
          goal = "Prefix each row with > and a space",
          lines = { "  north", "s", "east" },
          check = { lines = { ">   north", "> s", "> east" } },
        },
      }
    ),
    a.drill(
      "selection-boundary-drill",
      "Repair selection boundaries",
      "Uppercase exact fields while preserving punctuation and adjacent words.",
      {
        "Use characterwise or linewise selection and `U`. `o` moves the active end; `gv` recovers the last selection.",
      },
      {
        {
          goal = "Uppercase amber birch, keep cedar lowercase",
          lines = { "amber birch cedar" },
          check = { lines = { "AMBER BIRCH cedar" } },
        },
        {
          goal = "Uppercase only beta inside brackets",
          lines = { "[beta] gamma" },
          cursor = { 1, 1 },
          check = { lines = { "[BETA] gamma" } },
        },
        {
          goal = "Uppercase the complete middle row only",
          lines = { "keep", "two words", "stay" },
          cursor = { 2, 0 },
          check = { lines = { "keep", "TWO WORDS", "stay" } },
        },
      }
    ),
    a.lesson(
      "block-append-ragged",
      "Append to lines of different length",
      "Append `;` to the end of all three lines.",
      {
        "Press `<C-v>jj` to start a block over the three lines, then `$` to extend it to the end of every line.",
        "Press `A`, type `;`, and press `<Esc>`. The text is appended to each line at its own end.",
        "Without `$` the block has one right edge, and `A` would pad the short line with spaces.",
      },
      { "alpha", "be", "gamma!" },
      { lines = { "alpha;", "be;", "gamma!;" } },
      { keywords = { "C-v", "$", "A", "block", "append" } }
    ),
    a.lesson(
      "block-change-column",
      "Change a block",
      "Change the leading `NO` of all three lines to `OK`.",
      {
        "Select the block with `<C-v>jje`: three lines down and to the end of the word.",
        "Press `c`, type `OK`, and press `<Esc>`. The typed text replaces the block on every line.",
        "`r{char}` would replace every character of the block with one character.",
      },
      { "NO alpha", "NO beta", "NO gamma" },
      { lines = { "OK alpha", "OK beta", "OK gamma" } },
      { keywords = { "C-v", "c", "block", "change" } }
    ),
    a.lesson(
      "visual-replace-underline",
      "Underline a heading",
      "Add a line of `=` under the heading, exactly as long as the heading.",
      {
        "Duplicate the heading with `yyp`.",
        "Select the copy with `V` and press `r=`: in Visual mode `r` replaces every selected character.",
        "The underline has the length of the heading, however long that is.",
      },
      { "Release notes", "body" },
      { lines = { "Release notes", "=============", "body" } },
      { keywords = { "yyp", "Vr=", "r", "underline", "heading" } }
    ),
    a.lesson(
      "visual-indent-repeat",
      "Indent a selection and repeat",
      "Indent the two inner lines by two levels.",
      {
        "Select the two inner lines with `jVj` and press `>`. The selection ends, and the lines are one level deeper.",
        "Press `.` to shift the same lines again. A count works too: `2>` in Visual mode shifts twice.",
        "`gv` selects the same lines again when you need them for another command.",
      },
      { "if ready then", "one()", "two()", "end" },
      { lines = { "if ready then", "    one()", "    two()", "end" } },
      { options = { shiftwidth = 2, expandtab = true }, keywords = { "V", ">", ".", "gv", "indent" } }
    ),
    a.drill(
      "block-append-change-drill",
      "Append, change and replace selections",
      "Edit several lines at once with a block or a linewise selection.",
      {
        "Use `<C-v>` with `$A` or `c`, and `V` with `r`.",
      },
      {
        {
          goal = "Append a comma to all three lines",
          lines = { "a", "bb", "ccc" },
          check = { lines = { "a,", "bb,", "ccc," } },
        },
        {
          goal = "Change the leading TODO of each line to DONE",
          lines = { "TODO a", "TODO b", "TODO c" },
          check = { lines = { "DONE a", "DONE b", "DONE c" } },
        },
        {
          goal = "Replace every character of line 2 with a dash",
          lines = { "Title", "xxxxx", "body" },
          cursor = { 2, 0 },
          check = { lines = { "Title", "-----", "body" } },
        },
      }
    ),
  },
}
