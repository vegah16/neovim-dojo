-- The prefix of every Dojo control key, and how text names those keys.
-- Engine and curriculum text is written with the default prefix (`,k`); it is
-- rewritten for display when another prefix is configured.
local M = { prefix = "," }

function M.set(prefix)
  assert(prefix == nil or (type(prefix) == "string" and prefix ~= ""), "Neovim Dojo prefix must be a key sequence")
  M.prefix = prefix or ","
end

function M.lhs(key)
  return M.prefix .. key
end

function M.text(text)
  if M.prefix == "," then
    return text
  end
  -- A control is a comma plus one letter, after a space, backtick or bracket.
  local shown = (" " .. text):gsub("([%s`%(]),(%a)%f[%A]", function(before, letter)
    return before .. M.prefix .. letter
  end)
  return shown:sub(2)
end

return M
