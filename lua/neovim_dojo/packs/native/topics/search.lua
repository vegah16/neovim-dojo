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
    a.lesson(
      "search-offset-end",
      "Land on the end of a match",
      "Search for `marker` and land on its last letter in the first line.",
      {
        "Type `/marker/e` and press `<CR>`. The offset `e` after the second slash puts the cursor on the end of the match.",
        "`/marker/e+1` lands one character after it and `/marker/+1` one line below. `n` keeps the offset.",
      },
      { "find the marker here", "another marker there" },
      { cursor = { 1, 14 }, search = "marker" },
      { keywords = { "/e", "offset", "search" } }
    ),
    a.lesson(
      "very-magic-alternation",
      "Search for one of several words",
      "With one search that finds both `error` and `fatal`, land on `fatal`.",
      {
        "Type `/\\v(error|fatal)` and press `<CR>`. `\\v` makes `(`, `|` and `)` special without backslashes.",
        "The first match is `error`. Press `n` for `fatal`.",
        "Without `\\v` the same pattern is `error\\|fatal`.",
      },
      { "logs: info warn error fatal debug" },
      {
        cursor = { 1, 22 },
        search_accepts = { "error", "fatal" },
        search_rejects = { "info", "warn", "debug" },
      },
      { keywords = { "\\v", "\\|", "alternation", "very magic" } }
    ),
    a.lesson(
      "delete-to-search-match",
      "Use a search as a motion",
      "Delete everything before `STOP` on the first line.",
      {
        "A search is a motion, so it works after an operator. Type `d/STOP` and press `<CR>`.",
        "The delete stops just before the match. `c/` and `y/` work the same way, and `?` searches backward.",
      },
      { "drop these words STOP keep the rest", "protected" },
      { lines = { "STOP keep the rest", "protected" } },
      { keywords = { "d/", "c/", "y/", "search motion" } }
    ),
    a.lesson(
      "visual-star-search",
      "Search for the selected text",
      "Select `a.b` and search for exactly that text, landing on the third line.",
      {
        "Select the WORD under the cursor with `viW`.",
        "Press `*`. In Visual mode Neovim searches for the selected text literally, so the `.` does not match the `x` of `axb`.",
        "`#` does the same backward.",
      },
      { "use a.b here", "axb is not it", "again a.b there" },
      { cursor = { 3, 6 }, search_accepts = { "a.b" }, search_rejects = { "axb" } },
      { source = { kind = "neovim" }, cursor = { 1, 4 }, keywords = { "v_*", "*", "visual", "literal" } }
    ),
    a.drill(
      "search-pattern-drill",
      "Search with offsets and alternatives",
      "Reach or edit text with one deliberate search.",
      {
        "Use an `e` offset, a `\\v(a|b)` alternation, or a search after an operator.",
      },
      {
        {
          goal = "Land on the last letter of the first token",
          lines = { "a token, a token" },
          check = { cursor = { 1, 6 }, search = "token" },
        },
        {
          goal = "One search that finds cat and dog; land on dog",
          lines = { "bird cat fish dog" },
          check = {
            cursor = { 1, 14 },
            search_accepts = { "cat", "dog" },
            search_rejects = { "bird", "fish" },
          },
        },
        {
          goal = "Delete from the cursor up to END",
          lines = { "junk junk END tail", "protected" },
          check = { lines = { "END tail", "protected" } },
        },
      }
    ),
  },
}
