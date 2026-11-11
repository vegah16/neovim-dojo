local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")

local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-remote-target")

local RemoteActions = {}
RemoteActions.__index = RemoteActions

local function set_lines(instance, lines, cursor)
  local buf = instance.context.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
end

local function register_text()
  return vim.trim(vim.fn.getreg('"'))
end

function RemoteActions:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    return ("Round %d/%d · %s"):format(self.completed + 1, self.rounds, self.specification.prompt)
  end
  return self.final_status or "Finished"
end

function RemoteActions:build_schedule()
  self.targets = pool.sample(self.specification.targets, self.rounds, self.random)
  self.target_rows = pool.schedule(vim.fn.range(2, self.rows), self.rounds, self.random)
  self.templates = pool.schedule(self.specification.templates, self.rounds, self.random)
  self.distractors = pool.sample(self.specification.distractors, self.rounds * (self.rows - 2), self.random)
end

function RemoteActions:clear_target()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
end

function RemoteActions:reset()
  self:clear_target()
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self.operation_seen = false
  self:build_schedule()
  set_lines(self, { "Press Enter to start this drill." }, { 1, 0 })
  vim.bo[self.context.buf].modifiable = false
  return self:status()
end

function RemoteActions:render_round()
  self:clear_target()
  local round = self.completed + 1
  local target = self.targets[round]
  local target_row = self.target_rows[round]
  local target_line = self.templates[round]:format(target)
  local distractor_offset = self.completed * (self.rows - 2)
  local lines = { self.specification.origin }
  local next_distractor = 1

  for row = 2, self.rows do
    if row == target_row then
      lines[row] = target_line
    else
      lines[row] = self.distractors[distractor_offset + next_distractor]
      next_distractor = next_distractor + 1
    end
  end

  local target_column = assert(target_line:find(target, 1, true)) - 1
  self.expected = {
    target = target,
    target_row = target_row,
    target_column = target_column,
    origin = { 1, 0 },
  }
  self.operation_seen = false
  set_lines(self, lines, self.expected.origin)
  vim.api.nvim_buf_set_extmark(self.context.buf, target_namespace, target_row - 1, target_column, {
    end_col = target_column + #target,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
  vim.api.nvim_buf_set_extmark(self.context.buf, target_namespace, 0, 0, {
    end_col = #self.specification.origin,
    hl_group = "DiagnosticInfo",
    priority = highlights.persistent_priority,
  })
end

function RemoteActions:start()
  if self.phase == "running" then
    return false
  end
  if self.phase == "finished" then
    self:reset()
  end
  self.completed = 0
  self.phase = "running"
  self.started_at = self.clock()
  vim.bo[self.context.buf].modifiable = true
  self:render_round()
  self.callbacks.status(self:status())
  return true
end

function RemoteActions:operation_matches()
  local line = vim.api.nvim_buf_get_lines(
    self.context.buf,
    self.expected.target_row - 1,
    self.expected.target_row,
    false
  )[1] or ""
  if self.specification.variant == "delete" then
    return not line:find(self.expected.target, 1, true)
  end
  if self.specification.variant == "yank" then
    return line:find(self.expected.target, 1, true) ~= nil and register_text() == self.expected.target
  end
  return not line:find(self.expected.target, 1, true) and line:find(self.specification.replacement, 1, true) ~= nil
end

function RemoteActions:at_origin()
  return vim.api.nvim_get_current_buf() == self.context.buf
    and vim.deep_equal(vim.api.nvim_win_get_cursor(0), self.expected.origin)
end

function RemoteActions:finish_round()
  if self.phase ~= "running" or not self.operation_seen or not self:operation_matches() or not self:at_origin() then
    return false
  end

  self.completed = self.completed + 1
  if self.completed < self.rounds then
    self:render_round()
    self.callbacks.status(self:status(), true)
    return true
  end

  self:clear_target()
  self.phase = "finished"
  vim.bo[self.context.buf].modified = false
  vim.bo[self.context.buf].modifiable = false
  local elapsed_ms = (self.clock() - self.started_at) / 1000000
  self.callbacks.complete({
    metric = "elapsed_ms",
    unit = "ms",
    value = elapsed_ms,
    lower_is_better = true,
    details = {
      rounds = self.rounds,
      variant = self.specification.variant,
      pool_size = #self.specification.targets,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function RemoteActions:on_event(event)
  if self.phase ~= "running" then
    return false
  end
  if self.specification.variant == "yank" and event.event == "TextYankPost" then
    self.operation_seen = true
  elseif self.specification.variant == "delete" and event.event == "TextChanged" then
    self.operation_seen = true
  elseif
    self.specification.variant == "change"
    and (event.event == "TextChanged" or event.event == "TextChangedI" or event.event == "InsertLeave")
  then
    self.operation_seen = true
  end

  if not self.operation_seen then
    return false
  end
  vim.schedule(function()
    self:finish_round()
  end)
  return false
end

function RemoteActions:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function RemoteActions:close()
  if vim.api.nvim_buf_is_valid(self.context.buf) then
    self:clear_target()
  end
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
  }, RemoteActions)
end

return M
