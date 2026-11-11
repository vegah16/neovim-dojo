local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")
local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-highlighted-target")

local WindowTargets = {}
WindowTargets.__index = WindowTargets

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function configure_buffer(buf, name, filetype)
  vim.bo[buf].swapfile = false
  if name and vim.api.nvim_buf_get_name(buf) == "" then
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].undofile = false
  vim.bo[buf].filetype = filetype or "text"
end

local function sorted_windows()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  table.sort(windows, function(left, right)
    return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
  end)
  return windows
end

function WindowTargets:owns_buffer(buf)
  return buf == self.context.buf or (self.secondary_buf and buf == self.secondary_buf)
end

function WindowTargets:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    return ("Round %d/%d · %s"):format(
      self.completed + 1,
      self.rounds,
      self.specification.prompt:format(self.targets[self.completed + 1])
    )
  end
  return self.final_status or "Finished"
end

function WindowTargets:create_layout()
  vim.bo[self.context.buf].bufhidden = "hide"
  vim.cmd("silent! only!")
  vim.api.nvim_win_set_buf(0, self.context.buf)
  if self.secondary_buf and vim.api.nvim_buf_is_valid(self.secondary_buf) then
    pcall(vim.api.nvim_buf_delete, self.secondary_buf, { force = true })
  end
  self.secondary_buf = vim.api.nvim_create_buf(false, true)
  configure_buffer(
    self.secondary_buf,
    ("neovim-dojo://%s/window-target"):format(self.context.lesson.id),
    self.context.lesson.filetype
  )
  vim.cmd.vsplit()
  self.windows = sorted_windows()
  assert(#self.windows == 2, "window-target drills require exactly two task windows")
  vim.api.nvim_win_set_buf(self.windows[1], self.context.buf)
  vim.api.nvim_win_set_buf(self.windows[2], self.secondary_buf)
end

function WindowTargets:build_schedule()
  self.targets = pool.sample(self.specification.targets, self.rounds, self.random)
  self.templates = pool.sample(self.specification.templates, self.rounds, self.random)
  self.target_rows = pool.schedule(vim.fn.range(1, self.rows), self.rounds, self.random)
  local distractors_per_round = self.rows * 2 - 1
  self.distractors = pool.sample(self.specification.distractors, self.rounds * distractors_per_round, self.random)
end

function WindowTargets:reset()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  if self.secondary_buf and vim.api.nvim_buf_is_valid(self.secondary_buf) then
    vim.api.nvim_buf_clear_namespace(self.secondary_buf, target_namespace, 0, -1)
  end
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self:build_schedule()
  self:create_layout()
  set_lines(self.context.buf, { "Press Enter to start this drill." })
  set_lines(self.secondary_buf, { "Targets appear in this window too." })
  vim.api.nvim_set_current_win(self.windows[1])
  vim.api.nvim_win_set_cursor(self.windows[1], { 1, 0 })
  return self:status()
end

function WindowTargets:render_round()
  self.rendering = true
  local round = self.completed + 1
  local target = self.targets[round]
  local target_line = self.templates[round]:format(target)
  local target_column = assert(target_line:find(target, 1, true)) - 1
  local target_row = self.target_rows[round]
  local distractor_offset = self.completed * (self.rows * 2 - 1)
  local next_distractor = 1
  local start_lines = {}
  local target_lines = {}

  for row = 1, self.rows do
    start_lines[row] = self.distractors[distractor_offset + next_distractor]
    next_distractor = next_distractor + 1
    if row == target_row then
      target_lines[row] = target_line
    else
      target_lines[row] = self.distractors[distractor_offset + next_distractor]
      next_distractor = next_distractor + 1
    end
  end

  local start_window_index = self.random(1, 2)
  local target_window_index = start_window_index == 1 and 2 or 1
  local start_win = self.windows[start_window_index]
  local target_win = self.windows[target_window_index]
  vim.api.nvim_win_set_buf(start_win, self.context.buf)
  vim.api.nvim_win_set_buf(target_win, self.secondary_buf)
  set_lines(self.context.buf, start_lines)
  set_lines(self.secondary_buf, target_lines)
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  vim.api.nvim_buf_clear_namespace(self.secondary_buf, target_namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(self.secondary_buf, target_namespace, target_row - 1, target_column, {
    end_col = target_column + #target,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
  vim.api.nvim_win_set_cursor(start_win, { 1, 0 })
  vim.api.nvim_win_set_cursor(target_win, { 1, 0 })
  vim.api.nvim_set_current_win(start_win)
  self.expected = {
    buf = self.secondary_buf,
    row = target_row,
    first_column = target_column,
    last_column = target_column + #target - 1,
  }
  self.rendering = false
end

function WindowTargets:start()
  if self.phase == "running" then
    return false
  end
  if self.phase == "finished" then
    self:reset()
  end
  self.completed = 0
  self.phase = "running"
  self.started_at = self.clock()
  self:render_round()
  self.callbacks.status(self:status(), true)
  return true
end

function WindowTargets:on_event(event)
  if self.rendering or self.phase ~= "running" or event.event ~= "CursorMoved" then
    return false
  end
  if vim.api.nvim_get_current_buf() ~= self.expected.buf then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  if
    cursor[1] ~= self.expected.row
    or cursor[2] < self.expected.first_column
    or cursor[2] > self.expected.last_column
  then
    return false
  end

  self.completed = self.completed + 1
  if self.completed < self.rounds then
    self:render_round()
    self.callbacks.status(self:status(), true)
    return true
  end

  self.phase = "finished"
  local elapsed_ms = (self.clock() - self.started_at) / 1000000
  self.callbacks.complete({
    metric = "elapsed_ms",
    unit = "ms",
    value = elapsed_ms,
    lower_is_better = true,
    details = {
      rounds = self.rounds,
      variant = self.specification.variant,
      windows = 2,
      pool_size = #self.specification.targets,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function WindowTargets:apply_mappings(buf)
  buf = buf or self.context.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = buf, desc = "Start or replay Dojo drill" })
end

function WindowTargets:close()
  if vim.api.nvim_buf_is_valid(self.context.buf) then
    vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  end
  if self.secondary_buf and vim.api.nvim_buf_is_valid(self.secondary_buf) then
    vim.api.nvim_buf_clear_namespace(self.secondary_buf, target_namespace, 0, -1)
    pcall(vim.api.nvim_buf_delete, self.secondary_buf, { force = true })
  end
  self.secondary_buf = nil
end

function M.new(context, specification, callbacks)
  return setmetatable({
    context = context,
    specification = specification,
    callbacks = callbacks,
    rounds = specification.rounds,
    rows = specification.rows,
    random = callbacks.random or pool.default_random,
    clock = callbacks.clock or (vim.uv or vim.loop).hrtime,
  }, WindowTargets)
end

return M
