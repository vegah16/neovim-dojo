local M = {}

-- Transient motion and search plugins may shade the whole buffer while active.
-- Persistent task cues must remain readable above those temporary layers.
M.persistent_priority = 6000
M.target = "NeovimDojoTarget"

local function define()
  -- A foreground-only warning colour can be indistinguishable from ordinary
  -- syntax captures (strings and built-in calls are common examples). Search
  -- supplies a bounded background cue that shows the exact node range while
  -- remaining theme-aware.
  vim.api.nvim_set_hl(0, M.target, { link = "Search" })
end

function M.setup()
  define()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("NeovimDojoHighlights", { clear = true }),
    callback = define,
    desc = "Restore Neovim Dojo highlight links",
  })
end

return M
