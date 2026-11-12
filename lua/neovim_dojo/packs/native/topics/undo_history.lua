local a = require("neovim_dojo.author")
return {
  id = "undo-history",
  title = "Undo History",
  description = "Recover and inspect branching native undo history.",
  topics = { "editing", "history" },
  source = { kind = "vim" },
  keywords = { "undo", "redo", "branch", "g-", "g+", ":earlier", ":later" },
  lessons = {
    {
      id = "recover-undo-branch",
      revision = 1,
      title = "Recover an abandoned undo branch",
      objective = "Recover `alpha` from an abandoned branch while keeping `beta` as the chosen state.",
      keywords = { "unnamed register", "yank", "reconcile", "chronological undo" },
      steps = {
        "Change `base` to `alpha`, undo with `u`, then change `base` to `beta`. You have now forked the history.",
        "Press `g-` to visit the older `alpha` state and yank `alpha` with `yiw`.",
        "Press `g+` to return chronologically to the newer `beta` state.",
        "Replace `none` with the yank, for example with `viwp`.",
      },
      hint = "`u` and `<C-r>` follow the current branch; `g-` and `g+` traverse changes chronologically across branches. Neovim preserves states but does not merge them, so yank wanted text before returning.",
      filetype = "text",
      lines = {
        "chosen = base",
        "recovered = none",
      },
      cues = {
        { line = 1, text = "base" },
        { line = 2, text = "none", highlight = "DiagnosticInfo" },
      },
      cursor = { 1, 9 },
      setup = { kind = "clear_undo_history", allow_undotree = true },
      check = {
        kind = "undo_branch",
        lines = {
          "chosen = beta",
          "recovered = alpha",
        },
      },
    },
    {
      id = "undo-branch-recovery-drill",
      revision = 1,
      kind = "drill",
      title = "Recover undo branches",
      objective = "Build two branches, recover a token from the abandoned branch, and keep the chosen branch five times.",
      keywords = { "unnamed register", "yank", "chronological undo", "timed", "personal best" },
      steps = {
        "Press `<CR>` when you are ready; read the branch A and branch B tokens in `STATUS`.",
        "Replace `base` with branch A, undo with `u`, then replace `base` with branch B.",
        "Use `g-` to visit branch A, yank its token with `yiw`, then use `g+` to return to branch B.",
        "Replace `none` with the saved branch A token. Complete five rounds to record a time.",
      },
      hint = "A reliable sequence is `ciwA<Esc>`, `u`, `ciwB<Esc>`, `g-`, `yiw`, `g+`, then `viwp` on `none`.",
      filetype = "text",
      drill = {
        kind = "undo_branches",
        variant = "undo_branch_recovery",
        rounds = 5,
        scenarios = {
          { abandoned = "amber", current = "violet" },
          { abandoned = "harbor", current = "comet" },
          { abandoned = "maple", current = "silver" },
          { abandoned = "raven", current = "coral" },
          { abandoned = "willow", current = "signal" },
        },
      },
    },
    a.lesson(
      "undo-time-travel",
      "Go back several changes at once",
      "Append ` one`, ` two` and ` three` as three separate changes, then go back two changes with one command.",
      {
        "Type `A one` and press `<Esc>`. Do the same for ` two` and ` three`: three changes.",
        "Run `:earlier 2`. The buffer returns to its state two changes ago, `start one`.",
        "`:later 2` goes forward again. Both also take time and file writes: `:earlier 10m`, `:earlier 1f`.",
      },
      { "start" },
      {
        lines = { "start one" },
        extra = function()
          local tree = vim.fn.undotree()
          return tree.seq_cur < tree.seq_last
        end,
      },
      { setup = { kind = "clear_undo_history" }, keywords = { ":earlier", ":later", "u", "C-r", "undo" } }
    ),
  },
}
