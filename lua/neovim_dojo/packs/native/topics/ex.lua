local a = require("neovim_dojo.author")
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
  },
}
