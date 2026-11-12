-- Small, outcome-based checks shared by lessons and scenario drills.
local M = {}

-- The window that shows the task buffer, preferring the current one.
local function window(buf)
  if vim.api.nvim_get_current_buf() == buf then
    return vim.api.nvim_get_current_win()
  end
  return vim.fn.bufwinid(buf)
end

local function register_matches(wanted)
  local value = vim.fn.getreg(wanted.name)
  if wanted.value and value ~= wanted.value then
    return false
  end
  if wanted.contains and not value:find(wanted.contains, 1, true) then
    return false
  end
  return wanted.value ~= nil or wanted.contains ~= nil
end

-- Folds are a property of a window: `closed` and `open` name buffer lines.
local function folds_match(buf, wanted)
  local win = window(buf)
  if win == -1 then
    return false
  end
  return vim.api.nvim_win_call(win, function()
    for _, line in ipairs(wanted.closed or {}) do
      if vim.fn.foldclosed(line) == -1 then
        return false
      end
    end
    for _, line in ipairs(wanted.open or {}) do
      if vim.fn.foldclosed(line) ~= -1 then
        return false
      end
    end
    return true
  end)
end

-- "top": the cursor line is as high in its window as 'scrolloff' allows.
local function winline_matches(buf, wanted)
  if vim.api.nvim_get_current_buf() ~= buf then
    return false
  end
  local height = vim.api.nvim_win_get_height(0)
  local offset = math.min(vim.wo.scrolloff >= 0 and vim.wo.scrolloff or vim.o.scrolloff, math.floor((height - 1) / 2))
  if wanted == "top" then
    return vim.fn.winline() == offset + 1
  end
  return false
end

-- The last search pattern, judged by what it finds rather than how it is
-- spelled. 'ignorecase' applies as in a search; keep the samples in one case.
local function search_matches(samples, expected)
  local pattern = vim.fn.getreg("/")
  if pattern == "" then
    return false
  end
  for _, sample in ipairs(samples or {}) do
    local ok, index = pcall(vim.fn.match, sample, pattern)
    if not ok or (index >= 0) ~= expected then
      return false
    end
  end
  return true
end

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
  if check.search_accepts and not search_matches(check.search_accepts, true) then
    return false
  end
  if check.search_rejects and not search_matches(check.search_rejects, false) then
    return false
  end
  if check.repeat_contains and not vim.fn.getreg("."):find(check.repeat_contains, 1, true) then
    return false
  end
  if check.register and not register_matches(check.register) then
    return false
  end
  if check.folds and not folds_match(buf, check.folds) then
    return false
  end
  if check.winline and not winline_matches(buf, check.winline) then
    return false
  end
  if check.extra and not check.extra(context) then
    return false
  end
  -- A check must name at least one state of its own; `search` and
  -- `repeat_contains` alone would pass on what an earlier task left behind.
  return check.lines ~= nil
    or check.cursor ~= nil
    or check.mark ~= nil
    or check.register ~= nil
    or check.folds ~= nil
    or check.winline ~= nil
    or check.extra ~= nil
end

return M
