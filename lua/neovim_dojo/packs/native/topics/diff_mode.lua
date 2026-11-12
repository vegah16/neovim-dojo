local w = require("neovim_dojo.workspace")

-- A window keeps its diff options when its buffer is replaced on reset.
local function leave_diff_mode()
  vim.cmd("diffoff!")
end

return {
  id = "diff-mode",
  title = "Diff Mode",
  description = "Compare two files side by side and move changes between them.",
  source = { kind = "vim" },
  bindings = { origin = "native" },
  topics = { "windows", "projects" },
  lessons = {
    w.lesson(
      "diff-two-files",
      "Compare two files",
      "Show `main.txt` and `other.txt` side by side in diff mode.",
      {
        "Run `:vertical diffsplit other.txt`. Both windows scroll together, the differing line is highlighted and equal lines can fold away.",
        "For two windows that are already open, run `:diffthis` in each. `:diffoff!` ends diff mode in every window of the tab.",
      },
      { "alpha", "beta", "gamma" },
      {
        extra = function(context)
          local wins = w.windows(context)
          if #wins ~= 2 then
            return false
          end
          local seen = {}
          for _, win in ipairs(wins) do
            if not vim.wo[win].diff then
              return false
            end
            seen[vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))] = true
          end
          return seen[w.path(context, "main.txt")] and seen[w.path(context, "other.txt")] or false
        end,
      },
      { files = { ["other.txt"] = { "alpha", "BETA", "gamma" } }, prepare = leave_diff_mode },
      { keywords = { ":diffsplit", ":diffthis", ":diffoff", "diff" } }
    ),
    w.lesson(
      "diff-obtain-put",
      "Move changes between two files",
      "Take `new beta` from `other.txt` into `main.txt`, and give `delta` from `main.txt` to `other.txt`.",
      {
        "Run `:vertical diffsplit other.txt`, then return to the `main.txt` window with `<C-w>p`.",
        "Press `]c` to jump to the first difference and `do` (diff obtain) to take the other file's version.",
        "Press `]c` again and `dp` (diff put) to push this file's version to the other file. `[c` jumps back. Both buffers then read the same; saving is up to you.",
      },
      { "alpha", "old beta", "gamma", "delta" },
      {
        files = {
          ["main.txt"] = { "alpha", "new beta", "gamma", "delta" },
          ["other.txt"] = { "alpha", "new beta", "gamma", "delta" },
        },
      },
      { files = { ["other.txt"] = { "alpha", "new beta", "gamma", "old delta" } }, prepare = leave_diff_mode },
      { keywords = { "]c", "[c", "do", "dp", ":diffget", ":diffput" } }
    ),
  },
}
