local M = {}

local builtins = {
  scenarios = require("neovim_dojo.drills.scenarios"),
  cursor_targets = require("neovim_dojo.drills.cursor_targets"),
  remote_actions = require("neovim_dojo.drills.remote_actions"),
  search_targets = require("neovim_dojo.drills.search_targets"),
  syntax_nodes = require("neovim_dojo.drills.syntax_nodes"),
  text_actions = require("neovim_dojo.drills.text_actions"),
  undo_branches = require("neovim_dojo.drills.undo_branches"),
  window_targets = require("neovim_dojo.drills.window_targets"),
}

function M.create(context, callbacks, custom_handlers)
  local specification = assert(context.lesson.drill, "drill specification is required")
  local handler = (custom_handlers or {})[specification.kind] or builtins[specification.kind]
  assert(handler, "unknown Neovim Dojo drill kind: " .. tostring(specification.kind))
  return handler.new(context, specification, callbacks)
end

function M.format_score(score)
  if not score then
    return "none"
  end
  if score.unit == "ms" then
    return ("%.2f s"):format(score.value / 1000)
  end
  return ("%s %s"):format(score.value, score.unit or "points")
end

return M
