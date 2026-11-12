local a = require("neovim_dojo.author")
local w = require("neovim_dojo.workspace")
return {
  id = "ranges-and-ex",
  title = "Ranges and Ex",
  description = "Bound replacements, captures and global commands to intended records.",
  source = { kind = "vim" },
  topics = { "command-line", "text-editing" },
  lessons = {
    a.lesson(
      "substitute-ranges",
      "Choose substitution ranges",
      "Replace `old` on lines 2 and 3 only.",
      {
        "Compare `:s` (current line), `:2,3s` (explicit range), `:%s` (whole file).",
        "Run `:2,3s/old/new/g`. A Visual selection followed by `:` supplies the line range `'<,'>`; it still addresses whole selected lines.",
      },
      { "old outside", "old inside old", "old inside", "old outside" },
      { lines = { "old outside", "new inside new", "new inside", "old outside" } },
      { keywords = { ":s", "range", "%", "'<,'>" } }
    ),
    a.lesson(
      "substitute-confirmation",
      "Confirm individual replacements",
      "Change only the first and last `red` to `blue`.",
      {
        "Use `:%s/red/blue/gc`, answer `y`, `n`, `y` to the three prompts.",
        "`c` asks for confirmation, `g` visits every match per line, `q` cancels remaining matches. Undo with `u` before retrying.",
      },
      { "red red red", "protected" },
      { lines = { "blue red blue", "protected" } },
      { keywords = { ":s", "gc", "confirmation", "undo" } }
    ),
    a.lesson(
      "substitute-captures",
      "Capture and reorder fields",
      "Turn two `name=value` records into `value: name` without touching the comment.",
      {
        "Run `:1,2s/\\v(\\w+)[=](\\d+)/\\2: \\1/`. `\\v` uses very-magic grouping; `\\1` and `\\2` refer to captures.",
        "The range excludes the comment even though it looks like a matching record.",
      },
      { "alpha=12", "beta=7", "# alpha=99" },
      { lines = { "12: alpha", "7: beta", "# alpha=99" } },
      { keywords = { "capture", "\\v", "\\1", ":s" } }
    ),
    a.lesson(
      "bounded-global-normal",
      "Bound global and normal commands",
      "Uppercase only TODO rows in the first four lines.",
      {
        "Run `:1,4g/^TODO/normal! gUU`. Global selects matching lines; `normal!` applies native keys to each.",
        "`vglobal` selects nonmatching lines. Always constrain the range and pattern before running destructive commands.",
        "The final TODO is deliberately outside the range. `u` can undo the command; `,r` restores the whole fixture.",
      },
      { "TODO alpha", "keep beta", "TODO gamma", "keep delta", "TODO outside" },
      { lines = { "TODO ALPHA", "keep beta", "TODO GAMMA", "keep delta", "TODO outside" } },
      { keywords = { ":global", ":vglobal", ":normal!", "range" } }
    ),
    a.drill(
      "capture-transform-drill",
      "Transform captured fields",
      "Reorder bounded records with captures while preserving matching-looking comments.",
      {
        "Use a two-line range and captures; preserve the comment outside the range.",
      },
      {
        {
          goal = "Rewrite first two as value: name",
          lines = { "alpha=12", "beta=7", "# alpha=99" },
          check = { lines = { "12: alpha", "7: beta", "# alpha=99" } },
        },
        {
          goal = "Rewrite first two as value: name",
          lines = { "north=4", "south=28", "# south=9" },
          check = { lines = { "4: north", "28: south", "# south=9" } },
        },
        {
          goal = "Rewrite first two as value: name",
          lines = { "read=16", "write=3", "# read=1" },
          check = { lines = { "16: read", "3: write", "# read=1" } },
        },
      }
    ),
    a.drill(
      "filter-repair-drill",
      "Filter and repair selected records",
      "Use bounded global/vglobal commands to repair records and preserve outside matches.",
      {
        "Use `:g`/`:v` and an explicit range. Inspect the boundary row before checking.",
      },
      {
        {
          goal = "Uppercase TODO text in rows 1 through 3 only",
          lines = { "TODO alpha", "keep beta", "TODO gamma", "TODO outside" },
          check = { lines = { "TODO ALPHA", "keep beta", "TODO GAMMA", "TODO outside" } },
        },
        {
          goal = "Delete BAD rows in 1 through 3 only",
          lines = { "BAD stale", "keep", "BAD old", "BAD outside" },
          check = { lines = { "keep", "BAD outside" } },
        },
        {
          goal = "Append ! to non-comment rows 1 through 3 only",
          lines = { "# comment", "alpha", "beta", "outside" },
          check = { lines = { "# comment", "alpha!", "beta!", "outside" } },
        },
      }
    ),
    a.lesson(
      "copy-move-lines-ex",
      "Copy and move lines from the command line",
      "Copy `header` to the end of the buffer, and move `alpha` below `beta`.",
      {
        "`:t` copies lines and `:m` moves them; both take the line to put them below. Run `:1t$` to copy line 1 below the last line.",
        "Run `:2m3` to move line 2 below line 3. The cursor does not have to be near either line.",
        "`:t.` duplicates here, `:m0` moves to the top, and both take ranges: `:2,3t$`.",
      },
      { "header", "alpha", "beta", "footer" },
      { lines = { "header", "beta", "alpha", "footer", "header" } },
      { keywords = { ":t", ":copy", ":m", ":move", ":1t$", ":2m3" } }
    ),
    a.lesson(
      "sort-unique-lines",
      "Sort a range and drop duplicates",
      "Sort the fruit lines between the two comment lines and remove the duplicate.",
      {
        "Run `:2,5sort u`. `:sort` orders the lines of its range and `u` keeps one of each.",
        "Without a range it sorts the whole buffer and would move the comment lines.",
        "`:sort n` sorts by the first number in each line and `:sort!` reverses.",
      },
      { "# fruits", "pear", "apple", "pear", "fig", "# end" },
      { lines = { "# fruits", "apple", "fig", "pear", "# end" } },
      { keywords = { ":sort", ":sort u", ":sort n", "unique" } }
    ),
    a.lesson(
      "pattern-ranges",
      "Address lines by pattern",
      "Delete the lines between `BEGIN` and `END`, keeping both markers.",
      {
        "A pattern is a line address: `/BEGIN/` is the next line that matches. `+1` and `-1` shift an address by a line.",
        "Run `:/BEGIN/+1,/END/-1d`.",
        "Check a range first by using it with `:p`, which only prints the lines.",
      },
      { "keep", "BEGIN", "drop one", "drop two", "END", "keep" },
      { lines = { "keep", "BEGIN", "END", "keep" } },
      { keywords = { ":/pattern/", "range", "+1", "-1", ":d" } }
    ),
    a.lesson(
      "mark-relative-ranges",
      "Ranges relative to the cursor",
      "From the line `two`, delete it and the two lines after it with one command.",
      {
        "Move to `two`. In a range `.` is the current line, `+2` is two lines further and `$` is the last line.",
        "Run `:.,+2d`.",
        "Marks are addresses too: after `ma` and `mb`, `:'a,'bd` deletes from one to the other. Typing `:` with a count, as in `3:`, fills in `:.,.+2`.",
      },
      { "one", "two", "three", "four", "five", "six" },
      { lines = { "one", "five", "six" } },
      { keywords = { ":.,+2", ".", "$", "'a,'b", "range" } }
    ),
    a.lesson(
      "normal-on-range",
      "Run Normal keys on every line of a range",
      "Append `;` to the first three lines only.",
      {
        "Run `:1,3normal A;`. `:normal` types its keys on each line of the range, starting at column one.",
        "`:normal!` ignores mappings, which makes a command safe to share. `:%normal` would also change the comment.",
      },
      { "alpha", "beta", "gamma", "# note" },
      { lines = { "alpha;", "beta;", "gamma;", "# note" } },
      { keywords = { ":normal", ":normal!", "range" } }
    ),
    a.lesson(
      "substitute-case-modifiers",
      "Change case in a replacement",
      "Capitalize every word of the first two lines.",
      {
        "Run `:1,2s/\\<\\w/\\u&/g`. `\\<\\w` matches the first letter of a word, `&` is the matched text, and `\\u` uppercases the next character.",
        "`\\U` uppercases until `\\E`, and `\\l` and `\\L` lowercase.",
      },
      { "first name", "last name", "# keep lower" },
      { lines = { "First Name", "Last Name", "# keep lower" } },
      { keywords = { "\\u", "\\U", "\\l", "\\L", "\\E", "&", ":s" } }
    ),
    a.lesson(
      "substitute-expression",
      "Compute the replacement",
      "Double the number on each of the first two lines.",
      {
        "Run `:1,2s/\\d\\+/\\=submatch(0)*2/`. A replacement that starts with `\\=` is an expression.",
        "`submatch(0)` is the whole match and `submatch(1)` the first group. `\\=line('.')` would insert the line number.",
      },
      { "width=4", "height=10", "# depth=7" },
      { lines = { "width=8", "height=20", "# depth=7" } },
      { keywords = { "\\=", "submatch", ":s", "expression" } }
    ),
    a.lesson(
      "repeat-substitute",
      "Repeat the last substitution",
      "Replace every `old` with `new`: first on one line, then everywhere by repeating.",
      {
        "On the first line run `:s/old/new/g`.",
        "Press `g&` to repeat that substitution, with its flags, on every line.",
        "`&` repeats it on the current line only. In Neovim `&` keeps the flags; in Vim that is `:&&`.",
      },
      { "old a old", "old b old", "old c old" },
      { lines = { "new a new", "new b new", "new c new" } },
      { keywords = { "&", "g&", ":&&", ":s", "repeat" } }
    ),
    a.lesson(
      "collect-matching-lines",
      "Collect matching lines",
      "Copy every `TODO` line to the end of the buffer, in order.",
      {
        "Run `:g/^TODO/t$`. `:g` runs a command on each matching line, and `t$` copies that line to the end.",
        "`:g/pattern/m$` would move them instead, and `:g/pattern/d` deletes them.",
      },
      { "TODO one", "done", "TODO two", "done", "-- collected --" },
      { lines = { "TODO one", "done", "TODO two", "done", "-- collected --", "TODO one", "TODO two" } },
      { keywords = { ":g", ":global", "t$", "m$", "collect" } }
    ),
    w.lesson(
      "read-write-ranges",
      "Read a file in, write a range out",
      "Insert `notes.txt` below the first line, then write the first two lines to `part.txt`.",
      {
        "Run `:1r notes.txt`. `:r` (`:read`) inserts a file below the given line; without an address, below the cursor.",
        "Run `:1,2w part.txt`. `:w` with a range writes only those lines to the named file.",
        "`:r !date` inserts the output of a shell command, and `:w >> file` appends.",
      },
      { "head", "tail" },
      {
        files = {
          ["main.txt"] = { "head", "note one", "note two", "tail" },
          ["part.txt"] = { "head", "note one" },
        },
      },
      { files = { ["notes.txt"] = { "note one", "note two" } } },
      { keywords = { ":r", ":read", ":w", ":write", "range" } }
    ),
    a.lesson(
      "substitute-last-search",
      "Reuse the last search in a substitution",
      "Change `colour` to `color` in the first two lines, without typing the word again.",
      {
        "Press `*` on `colour` to search for it.",
        "Run `:1,2s//color/g`. An empty pattern means the last search pattern.",
        "This lets you get a pattern right with `/` first and substitute afterwards.",
      },
      { "colour colour", "the colour", "# colour" },
      { lines = { "color color", "the color", "# colour" } },
      { keywords = { ":s//", "*", "last search", "empty pattern" } }
    ),
    a.lesson(
      "strip-trailing-retab",
      "Remove trailing spaces and tabs",
      "Remove the trailing spaces, and turn the leading tab into four spaces.",
      {
        "Run `:%s/\\s\\+$//`. `\\s\\+$` is one or more white-space characters at the end of a line.",
        "Run `:retab`. With 'expandtab' set it replaces each tab with spaces, at the width of 'tabstop'.",
        "`:set list` shows tabs and trailing spaces.",
      },
      { "alpha   ", "\tbeta  ", "gamma" },
      { lines = { "alpha", "    beta", "gamma" } },
      {
        options = { tabstop = 4, expandtab = true },
        keywords = { "\\s\\+$", ":retab", "trailing", "tab", ":set list" },
      }
    ),
    a.lesson(
      "repeat-last-ex-command",
      "Repeat the last command line",
      "Make four copies of the first line by running one command and repeating it.",
      {
        "Run `:t.` to duplicate the current line.",
        "Press `@:` to run the last command line again, and `@@` to repeat that.",
        "`@:` takes a count: `5@:` runs the command five times.",
      },
      { "row", "end" },
      { lines = { "row", "row", "row", "row", "end" } },
      { keywords = { "@:", "@@", ":t.", "repeat" } }
    ),
    a.drill(
      "ex-line-surgery-drill",
      "Rearrange lines from the command line",
      "Copy, move, sort and delete lines by address.",
      {
        "Use `:t`, `:m`, `:sort`, `:d` and `:normal` with a range. Line numbers, `$` and patterns are all addresses.",
      },
      {
        {
          goal = "Copy line 1 below line 3",
          lines = { "a", "b", "c", "d" },
          check = { lines = { "a", "b", "c", "a", "d" } },
        },
        {
          goal = "Move the last line to the top",
          lines = { "b", "c", "a" },
          check = { lines = { "a", "b", "c" } },
        },
        {
          goal = "Sort lines 2 to 4; keep the first and last line",
          lines = { "# head", "pear", "apple", "fig", "# tail" },
          check = { lines = { "# head", "apple", "fig", "pear", "# tail" } },
        },
        {
          goal = "Delete the lines between BEGIN and END; keep both",
          lines = { "top", "BEGIN", "x", "y", "END", "keep" },
          check = { lines = { "top", "BEGIN", "END", "keep" } },
        },
        {
          goal = "Append a comma to lines 1 to 3",
          lines = { "a", "b", "c", "end" },
          check = { lines = { "a,", "b,", "c,", "end" } },
        },
      }
    ),
    a.drill(
      "substitute-power-drill",
      "Substitute with modifiers and expressions",
      "Transform bounded lines with case modifiers, expressions and precise patterns.",
      {
        "Use `\\u`, `\\U`, `\\=` and `\\zs` in `:s`. Keep the range to the requested lines.",
      },
      {
        {
          goal = "Capitalize every word in lines 1 and 2",
          lines = { "red fox", "blue jay", "# keep low" },
          check = { lines = { "Red Fox", "Blue Jay", "# keep low" } },
        },
        {
          goal = "Double the numbers in lines 1 and 2",
          lines = { "a=2", "b=15", "# c=4" },
          check = { lines = { "a=4", "b=30", "# c=4" } },
        },
        {
          goal = "Remove the trailing spaces on every line",
          lines = { "x  ", "y ", "z" },
          check = { lines = { "x", "y", "z" } },
        },
        {
          goal = "Uppercase the word after id: in lines 1 and 2",
          lines = { "id: abc", "id: xyz", "# id: low" },
          check = { lines = { "id: ABC", "id: XYZ", "# id: low" } },
        },
      }
    ),
  },
}
