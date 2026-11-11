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
  },
}
