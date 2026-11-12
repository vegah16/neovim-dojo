local w = require("neovim_dojo.workspace")

local files = {
  ["alpha.txt"] = { "TODO alpha", "keep" },
  ["beta.txt"] = { "TODO beta", "keep" },
  ["gamma.txt"] = { "TODO gamma" },
}
-- The learner's own quickfix list comes back when the task closes.
local function keep_quickfix(context)
  context.workspace.qf = vim.fn.getqflist({ items = 0, title = 0, context = 0, idx = 0 })
end

return {
  id = "quickfix",
  title = "Native Quickfix",
  description = "Collect locations in a list, walk it, and change every entry with one command.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "search", "projects" },
  lessons = {
    w.lesson(
      "vimgrep-quickfix",
      "Search files into the quickfix list",
      "Collect every `TODO` of the project's text files in the quickfix list, and jump to the one in `beta.txt`.",
      {
        "Run `:vimgrep /TODO/ **/*.txt`. Neovim searches the files, fills the quickfix list and jumps to the first match.",
        "Run `:cnext` to jump to the next match, in `beta.txt`. `:copen` shows the whole list in a window.",
        "`:vimgrep` needs no external program. `:grep` uses 'grepprg' and is faster on a large project.",
      },
      { "search origin" },
      {
        position = { file = "beta.txt", cursor = { 1, 0 } },
        extra = function()
          return #vim.fn.getqflist() == 3
        end,
      },
      { files = files, prepare = keep_quickfix },
      { keywords = { ":vimgrep", ":cnext", ":copen", ":grep", "quickfix" } }
    ),
    w.lesson(
      "quickfix-first-last",
      "Walk the quickfix list",
      "The quickfix list holds three entries. Jump to the last one.",
      {
        "Run `:clast`. `:cfirst` goes to the first entry, and `:cnext` and `:cprevious` step.",
        "`:cc 2` jumps to entry 2. Neovim 0.11 and later also map `]q`, `[q`, `]Q` and `[Q`.",
        "`:cclose` closes the list window; the list itself stays until another replaces it, and `:colder` brings an earlier list back.",
      },
      { "quickfix origin" },
      { position = { file = "gamma.txt", cursor = { 1, 0 } } },
      { files = files, model = "qf", results = { "alpha.txt", "beta.txt", "gamma.txt" } },
      { keywords = { ":clast", ":cfirst", ":cnext", ":cprevious", ":cc", "]q", "[q", ":colder" } }
    ),
    w.lesson(
      "cdo-batch-change",
      "Change every quickfix entry",
      "The list names the first line of `alpha.txt` and `beta.txt`. Change `TODO` to `DONE` on both and save, without touching `gamma.txt`.",
      {
        "Run `:cdo s/TODO/DONE/ | update`. `:cdo` runs a command on the line of every quickfix entry, and `update` writes each changed file.",
        "`:cfdo` runs once per file instead: `:cfdo %s/TODO/DONE/ge | update`.",
        "Only listed entries change, so the list is the review step: remove entries you do not want before running the command.",
      },
      { "batch origin" },
      {
        disk = true,
        files = {
          ["alpha.txt"] = { "DONE alpha", "keep" },
          ["beta.txt"] = { "DONE beta", "keep" },
          ["gamma.txt"] = { "TODO gamma" },
        },
      },
      { files = files, model = "qf", results = { "alpha.txt", "beta.txt" } },
      { keywords = { ":cdo", ":cfdo", "update", "batch" } }
    ),
    w.lesson(
      "location-list-local",
      "A list for one window",
      "Search `TODO` into this window's location list, and jump to the match in `beta.txt`.",
      {
        "Run `:lvimgrep /TODO/ **/*.txt`. A location list works like the quickfix list but belongs to one window, so it does not replace the quickfix list.",
        "Run `:lnext` for the match in `beta.txt`. `:lopen` shows the list, and `:ldo` changes every entry.",
        "Every quickfix command has a location-list twin that starts with `l`.",
      },
      { "location origin" },
      {
        position = { file = "beta.txt", cursor = { 1, 0 } },
        extra = function()
          return #vim.fn.getloclist(0) == 3
        end,
      },
      { files = files },
      { keywords = { ":lvimgrep", ":lnext", ":lopen", ":ldo", "location list" } }
    ),
    w.drill(
      "quickfix-batch-drill",
      "Change files through the quickfix list",
      "Apply one command to every entry of a prepared quickfix list and save the files.",
      {
        "Each round fills the quickfix list. Use `:cdo` with a command and `| update`; files that are not listed must stay unchanged.",
      },
      {
        {
          goal = "Change TODO to DONE on every listed line and save",
          lines = { "round origin" },
          model = "qf",
          results = { "alpha.txt", "beta.txt" },
          check = {
            disk = true,
            files = {
              ["alpha.txt"] = { "DONE alpha", "keep" },
              ["beta.txt"] = { "DONE beta", "keep" },
              ["gamma.txt"] = { "TODO gamma" },
            },
          },
        },
        {
          goal = "Append a space and checked to every listed line and save",
          lines = { "round origin" },
          model = "qf",
          results = { "alpha.txt", "gamma.txt" },
          check = {
            disk = true,
            files = {
              ["alpha.txt"] = { "TODO alpha checked", "keep" },
              ["beta.txt"] = { "TODO beta", "keep" },
              ["gamma.txt"] = { "TODO gamma checked" },
            },
          },
        },
        {
          goal = "Delete every listed line and save",
          lines = { "round origin" },
          model = "qf",
          results = { "alpha.txt", "beta.txt" },
          check = {
            disk = true,
            files = {
              ["alpha.txt"] = { "keep" },
              ["beta.txt"] = { "keep" },
              ["gamma.txt"] = { "TODO gamma" },
            },
          },
        },
      },
      { files = files }
    ),
  },
}
