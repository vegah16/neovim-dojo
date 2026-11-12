local a = require("neovim_dojo.author")

-- Folds follow the indent, and every fold starts open.
local by_indent = { foldmethod = "indent", foldlevel = 99, foldenable = true, shiftwidth = 2 }
local closed = vim.tbl_extend("force", by_indent, { foldlevel = 0 })
local two_functions = {
  "function alpha()",
  "  local a = 1",
  "  return a",
  "end",
  "function beta()",
  "  local b = 2",
  "  return b",
  "end",
}
local three_functions = vim.list_extend(vim.list_slice(two_functions), {
  "function gamma()",
  "  local c = 3",
  "  return c",
  "end",
})

return {
  id = "folding",
  title = "Folds",
  description = "Hide and show parts of a buffer, and treat a closed fold as one line.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "structure" },
  lessons = {
    a.lesson(
      "toggle-fold-under-cursor",
      "Close and open one fold",
      "Close the fold that holds the body of `alpha`, and leave the body of `beta` open.",
      {
        "This task folds by indent: each indented body is a fold, and all start open.",
        "With the cursor in the body of `alpha`, press `zc` to close its fold. `zo` opens it and `za` toggles.",
        "A closed fold shows as one line with a count of the lines it hides.",
      },
      two_functions,
      { folds = { closed = { 2 }, open = { 6 } } },
      { cursor = { 2, 2 }, options = by_indent, keywords = { "zc", "zo", "za", "fold" } }
    ),
    a.lesson(
      "close-open-all-folds",
      "Close all folds, then open one",
      "Close every fold, then open only the body of `beta`.",
      {
        "Press `zM` to close all folds: the buffer becomes an outline.",
        "Move to the closed fold under `function beta()` and press `zo`.",
        "`zR` opens every fold again. `zj` and `zk` move to the next and the previous fold.",
      },
      three_functions,
      { folds = { closed = { 2, 10 }, open = { 6 } } },
      { options = by_indent, keywords = { "zM", "zR", "zo", "zj", "zk", "outline" } }
    ),
    a.lesson("create-manual-fold", "Create a fold by hand", "Fold the three `noise` lines into one closed fold.", {
      "With manual folding, `zf` followed by a motion creates a fold, closed at once.",
      "On `noise 1` type `zf2j`: this line and the two below it.",
      "`zd` deletes the fold under the cursor, not its text. `zfap` folds a paragraph.",
    }, { "keep", "noise 1", "noise 2", "noise 3", "keep" }, { folds = { closed = { 2, 3, 4 }, open = { 1, 5 } } }, {
      options = { foldmethod = "manual", foldenable = true },
      keywords = { "zf", "zd", "zf2j", "zfap", "manual fold" },
    }),
    a.lesson(
      "edit-closed-fold",
      "Edit a closed fold as one line",
      "Close the fold with the two stale lines and delete it with one `dd`.",
      {
        "Move into the stale lines and press `zc`.",
        "On the closed fold press `dd`. Linewise commands treat a closed fold as a single line, so both lines go.",
        "`yy`, `p`, `>>` and `:m` see it the same way, which makes moving a whole function a short command.",
      },
      { "function alpha()", "  stale one", "  stale two", "end", "keep" },
      { lines = { "function alpha()", "end", "keep" } },
      { options = by_indent, keywords = { "zc", "dd", "fold", "linewise" } }
    ),
    a.drill("fold-control-drill", "Control folds", "Bring the folds into the requested state.", {
      "Each round folds by indent. Use `zc`, `zo`, `zM` and `zR`; the open and closed folds are checked.",
    }, {
      {
        goal = "Close only the first fold",
        lines = two_functions,
        options = by_indent,
        check = { folds = { closed = { 2 }, open = { 6 } } },
      },
      {
        goal = "Close every fold",
        lines = two_functions,
        options = by_indent,
        check = { folds = { closed = { 2, 6 } } },
      },
      {
        goal = "Open every fold",
        lines = two_functions,
        options = closed,
        check = { folds = { open = { 2, 6 } } },
      },
      {
        goal = "Open only the second fold",
        lines = two_functions,
        options = closed,
        check = { folds = { closed = { 2 }, open = { 6 } } },
      },
    }),
  },
}
