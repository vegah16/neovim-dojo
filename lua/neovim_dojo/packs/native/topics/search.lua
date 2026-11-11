local a = require("neovim_dojo.author")
return {
  id = "native-search",
  title = "Native Search",
  description = "Literal and whole-word search, direction, and precise repeated changes.",
  source = { kind = "vim" },
  topics = { "movement", "text-editing" },
  lessons = {
    a.lesson(
      "literal-search-case",
      "Literal search and case",
      "Find the literal, case-sensitive `A.b` on the third line.",
      {
        "Type `/\\V\\CA.b<CR>`: `\\V` makes punctuation literal and `\\C` forces case sensitivity.",
        "The lowercase and wildcard lookalikes must not be selected.",
      },
      { "a.b", "Axb", "A.b", "end" },
      { cursor = { 3, 0 }, search = "\\V\\CA.b" },
      { keywords = { "/", "\\V", "\\C", "\\c", "case" } }
    ),
    a.lesson(
      "whole-word-star-hash",
      "Whole-word search with star and hash",
      "Use a whole-word search to find the second `task`, passing `tasking`.",
      {
        "With the cursor on `task`, press `*` for the next whole-word occurrence.",
        "`#` searches backward for that word. `g*` and `g#` allow substring matches; compare after reset.",
      },
      { "task tasking task" },
      { cursor = { 1, 13 }, search = "\\<task\\>" },
      { keywords = { "*", "#", "g*", "g#", "whole word" } }
    ),
    a.lesson(
      "search-direction-next",
      "Search direction and n/N",
      "Reach the middle occurrence of `signal` from a backward search.",
      {
        "From the last row, type `?signal<CR>` to search backward.",
        "`n` repeats the original direction; `N` reverses it. Finish on the middle row, column zero.",
        "Search highlighting is independent of search direction; resetting this fixture does not clear native search history.",
      },
      { "signal north", "signal middle", "signal south" },
      { cursor = { 2, 0 }, search = "signal" },
      { cursor = { 3, 0 }, keywords = { "?", "n", "N", "direction" } }
    ),
    a.lesson(
      "change-next-match",
      "Change a match with cgn",
      "Change both complete `old` words to `ready`, leaving `oldish` alone.",
      {
        "Search `/\\<old\\><CR>`, use `cgnready<Esc>`, then press `.` for the next matching word.",
        "`cgn` selects a search match for change; dot can seek and change the next match. Check every occurrence before using a count.",
      },
      { "old oldish old", "protected" },
      { lines = { "ready oldish ready", "protected" }, repeat_contains = "ready" },
      { keywords = { "cgn", ".", "\\<", "\\>" } }
    ),
    a.drill(
      "search-occurrence-drill",
      "Find requested occurrences",
      "Reach exact matches among case, substring and direction distractors.",
      {
        "Use native search flags and n/N. The requested location and search pattern are checked where relevant.",
      },
      {
        {
          goal = "Find literal A.b, case-sensitive",
          lines = { "a.b", "Axb", "A.b" },
          check = { cursor = { 3, 0 }, search = "\\V\\CA.b" },
        },
        {
          goal = "Use star to reach second complete task",
          lines = { "task tasking task" },
          check = { cursor = { 1, 13 }, search = "\\<task\\>" },
        },
        {
          goal = "Search backward to the middle signal",
          lines = { "signal north", "signal middle", "signal south" },
          cursor = { 3, 0 },
          check = { cursor = { 2, 0 }, search = "signal" },
        },
      }
    ),
    a.drill(
      "search-change-decoys-drill",
      "Change matches, preserve decoys",
      "Use search-driven edits across varied records while keeping similar words.",
      {
        "Choose a bounded pattern, change matches with `cgn` and `.`, and inspect the preserved decoys before checking.",
      },
      {
        {
          goal = "Change old words to ready; keep oldish",
          lines = { "old oldish old", "protected" },
          check = { lines = { "ready oldish ready", "protected" } },
        },
        {
          goal = "Change cat words to fox; keep catalog",
          lines = { "cat catalog cat", "protected" },
          check = { lines = { "fox catalog fox", "protected" } },
        },
        {
          goal = "Change run words to walk; keep runner",
          lines = { "run runner run", "protected" },
          check = { lines = { "walk runner walk", "protected" } },
        },
      }
    ),
  },
}
