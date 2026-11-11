-- Small, outcome-based checks shared by lessons and scenario drills.
local M = {}

function M.matches(context, check)
  local buf = context.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if check.lines and not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), check.lines) then
    return false
  end
  if check.cursor then
    if vim.api.nvim_get_current_buf() ~= buf then
      return false
    end
    if not vim.deep_equal(vim.api.nvim_win_get_cursor(0), check.cursor) then
      return false
    end
  end
  if check.mark then
    if not vim.deep_equal(vim.api.nvim_buf_get_mark(buf, check.mark.name), check.mark.position) then
      return false
    end
  end
  if check.search and vim.fn.getreg("/") ~= check.search then
    return false
  end
  if check.repeat_contains and not vim.fn.getreg("."):find(check.repeat_contains, 1, true) then
    return false
  end
  return check.lines ~= nil or check.cursor ~= nil or check.mark ~= nil
end

return M
