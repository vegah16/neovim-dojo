local a = require("neovim_dojo.author")
return {
  id = "text-objects",
  title = "Native Text Objects",
  description = "Operate on words, quotes, brackets, paragraphs, sentences and tags from anywhere inside them.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "text-editing", "structure" },
  lessons = {
    a.lesson(
      "inner-around-word",
      "Inner word and a word",
      "Delete `obsolete` so that exactly one space remains between the other words.",
      {
        "A text object follows an operator and needs no motion to its start: the cursor may be anywhere in the word.",
        "`diw` deletes the inner word and leaves both spaces. `daw` deletes a word with one neighbouring space.",
        "Use `daw`. Reset with `,r` and try `diw` to see the difference.",
      },
      { "alpha obsolete gamma" },
      { lines = { "alpha gamma" } },
      { cursor = { 1, 9 }, keywords = { "iw", "aw", "diw", "daw", "text object" } }
    ),
    a.lesson(
      "quote-objects",
      "Inside and around quotes",
      "Replace the quoted text with `final`, keeping the quotes and the comment.",
      {
        'Type `ci"`, then `final`, then `<Esc>`. `i"` is the text between the quotes.',
        "The cursor starts before the quotes: on the same line, a quote object looks ahead for the next quoted string.",
        "`a\"` includes the quotes. `i'` does the same for single quotes, and there is an object for backticks too.",
      },
      { 'title = "old draft" -- keep' },
      { lines = { 'title = "final" -- keep' } },
      { keywords = { 'ci"', 'i"', 'a"', "i'", "quote" } }
    ),
    a.lesson(
      "bracket-objects",
      "Inside and around brackets",
      "Empty the parentheses of `sum`, and remove `[index]` with its brackets.",
      {
        "The cursor is inside the parentheses. `di(` deletes what is inside them; `dib` is the same object.",
        "Move into the square brackets, for example with `f[`, and type `da[`: around includes the brackets.",
        "`i{`/`a{` (also `iB`/`aB`) and `i<`/`a<` follow the same rule.",
      },
      { "total = sum(first, second) * rate[index]" },
      { lines = { "total = sum() * rate" } },
      { cursor = { 1, 14 }, keywords = { "i(", "a(", "ib", "i[", "a[", "i{", "bracket" } }
    ),
    a.lesson(
      "paragraph-object",
      "A paragraph as an object",
      "Delete the two stale lines and one of the blank lines around them.",
      {
        "`ap` is a paragraph with a blank line after it, and `ip` is only its lines.",
        "With the cursor in the stale paragraph, type `dap`.",
        "`yap` copies a paragraph, `vip` selects one, and `>ip` indents one.",
      },
      { "intro line", "", "stale one", "stale two", "", "closing line" },
      { lines = { "intro line", "", "closing line" } },
      { cursor = { 3, 0 }, keywords = { "ip", "ap", "dap", "paragraph" } }
    ),
    a.lesson(
      "sentence-object",
      "A sentence as an object",
      "Delete the middle sentence and keep one space between the other two.",
      {
        "A sentence ends at `.`, `!` or `?` followed by a space or the end of the line.",
        "With the cursor in the middle sentence, type `das`: a sentence with its trailing space. `dis` would leave the space.",
        "`(` and `)` move by sentence.",
      },
      { "Keep this. Remove this sentence. Keep that too." },
      { lines = { "Keep this. Keep that too." } },
      { cursor = { 1, 15 }, keywords = { "is", "as", "das", "sentence", "(", ")" } }
    ),
    a.lesson(
      "tag-object",
      "Inside and around a tag",
      "Change the text inside the `<b>` tag to `new`.",
      {
        "The cursor is on `bold`. Type `cit`, then `new`, then `<Esc>`: `it` is what is between the nearest pair of tags.",
        "`at` includes the tags, so `dat` would remove `<b>…</b>` whole. A count takes the next tag outward: `d2at`.",
      },
      { "<p>old <b>bold</b> text</p>" },
      { lines = { "<p>old <b>new</b> text</p>" } },
      { cursor = { 1, 10 }, keywords = { "it", "at", "cit", "dat", "tag" } }
    ),
    a.lesson(
      "counted-objects",
      "Reach an outer object with a count",
      "Empty the parentheses of `outer`, from the cursor inside `inner(...)`.",
      {
        "A count before a bracket object selects that many levels outward.",
        "The cursor is on `value`. `di(` would empty the innermost parentheses. Type `d2i(` to empty the ones of `outer`.",
        "In Visual mode, repeating the object grows the selection: `vi(` and then `i(` again.",
      },
      { "call(outer(inner(value)), keep)" },
      { lines = { "call(outer(), keep)" } },
      { cursor = { 1, 18 }, keywords = { "2i(", "d2i(", "count", "nested" } }
    ),
    a.drill("text-object-drill", "Pick the text object", "Make each edit with one operator and one text object.", {
      "The cursor starts inside the text to change. Use `aw`, a quote object, a bracket object, `ap` or `it`.",
    }, {
      {
        goal = "Delete the word extra and one space",
        lines = { "keep extra words", "protected" },
        cursor = { 1, 6 },
        check = { lines = { "keep words", "protected" } },
      },
      {
        goal = "Change the text in single quotes to ok",
        lines = { "msg = 'failed badly'", "protected" },
        cursor = { 1, 8 },
        check = { lines = { "msg = 'ok'", "protected" } },
      },
      {
        goal = "Delete the square brackets and their content",
        lines = { "list[stale] = 1", "protected" },
        cursor = { 1, 6 },
        check = { lines = { "list = 1", "protected" } },
      },
      {
        goal = "Delete the middle paragraph and one blank line",
        lines = { "top", "", "mid a", "mid b", "", "end" },
        cursor = { 3, 0 },
        check = { lines = { "top", "", "end" } },
      },
      {
        goal = "Change the content of the tag to x",
        lines = { "<i>stale</i>", "protected" },
        cursor = { 1, 4 },
        check = { lines = { "<i>x</i>", "protected" } },
      },
    }),
    a.drill(
      "object-operator-drill",
      "Combine operators with objects",
      "Apply an operator other than delete or change to a text object.",
      {
        "Any operator takes a text object: `gU` uppercases, `y` yanks, `>` indents, `d` deletes.",
      },
      {
        {
          goal = "Uppercase the text inside the parentheses",
          lines = { "call(alpha beta) tail", "protected" },
          cursor = { 1, 6 },
          check = { lines = { "call(ALPHA BETA) tail", "protected" } },
        },
        {
          goal = "Yank inside the braces and paste it at the end of the line",
          lines = { "{core} = ", "protected" },
          cursor = { 1, 2 },
          check = { lines = { "{core} = core", "protected" } },
        },
        {
          goal = "Indent the paragraph under the cursor once (two spaces)",
          lines = { "head", "", "one", "two", "", "tail" },
          cursor = { 3, 0 },
          options = { shiftwidth = 2, expandtab = true },
          check = { lines = { "head", "", "  one", "  two", "", "tail" } },
        },
        {
          goal = "Delete the sentence under the cursor",
          lines = { "One stays. Two goes. Three stays." },
          cursor = { 1, 12 },
          check = { lines = { "One stays. Three stays." } },
        },
      }
    ),
  },
}
