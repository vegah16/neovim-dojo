local M = {}
local pool = require("neovim_dojo.drills.pool")

local UndoBranches = {}
UndoBranches.__index = UndoBranches

-- Shared with the session's native undo lesson setup and check.
function M.has_alternate(entries)
  for _, entry in ipairs(entries or {}) do
    if type(entry.alt) == "table" and #entry.alt > 0 then
      return true
    end
    if M.has_alternate(entry.entries) or M.has_alternate(entry.alt) then
      return true
    end
  end
  return false
end

function M.clear_history(buf)
  local undolevels = vim.bo[buf].undolevels
  vim.bo[buf].undolevels = -1
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { first .. " " })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { first })
  vim.bo[buf].undolevels = undolevels
  vim.bo[buf].modified = false
end

local function set_lines(instance, lines, cursor)
  local buf = instance.context.buf
  -- Undotree ignores `nofile`; `acwrite` remains disposable but lets users
  -- inspect the native graph while practising this drill.
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  M.clear_history(buf)
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(0, cursor)
end

function UndoBranches:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    local scenario = self.schedule[self.completed + 1]
    return ("Round %d/%d · branch A: %s · branch B: %s · recover %s"):format(
      self.completed + 1,
      self.rounds,
      scenario.abandoned,
      scenario.current,
      scenario.abandoned
    )
  end
  return self.final_status or "Finished"
end

function UndoBranches:reset()
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self.schedule = pool.schedule(self.specification.scenarios, self.rounds, self.random)
  set_lines(self, { "Press Enter to start this drill." }, { 1, 0 })
  vim.bo[self.context.buf].modifiable = false
  return self:status()
end

function UndoBranches:render_round()
  self.expected = self.schedule[self.completed + 1]
  set_lines(self, { "chosen = base", "recovered = none" }, { 1, 9 })
end

function UndoBranches:start()
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
  self.callbacks.status(self:status())
  return true
end

function UndoBranches:on_event(event)
  if self.phase ~= "running" or vim.api.nvim_get_current_buf() ~= self.context.buf then
    return false
  end
  if event.event ~= "TextChanged" and event.event ~= "InsertLeave" then
    return false
  end

  local expected = {
    "chosen = " .. self.expected.current,
    "recovered = " .. self.expected.abandoned,
  }
  local lines = vim.api.nvim_buf_get_lines(self.context.buf, 0, -1, false)
  if not vim.deep_equal(lines, expected) or not M.has_alternate(vim.fn.undotree().entries) then
    return false
  end

  self.completed = self.completed + 1
  if self.completed < self.rounds then
    self:render_round()
    self.callbacks.status(self:status(), true)
    return true
  end

  self.phase = "finished"
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
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function UndoBranches:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function UndoBranches:close() end

function M.new(context, specification, callbacks)
  return setmetatable({
    context = context,
    specification = specification,
    callbacks = callbacks,
    rounds = specification.rounds,
    random = callbacks.random or pool.default_random,
    clock = callbacks.clock or (vim.uv or vim.loop).hrtime,
  }, UndoBranches)
end

return M
