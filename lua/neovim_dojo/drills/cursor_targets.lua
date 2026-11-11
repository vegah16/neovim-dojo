local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")

local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-target")

local CursorTargets = {}
CursorTargets.__index = CursorTargets

local function candidates_from(position, rows, columns, distance)
  local candidates = {}
  for row = 1, rows do
    for column = 1, columns do
      if math.abs(row - position.row) + math.abs(column - position.column) == distance then
        candidates[#candidates + 1] = { row = row, column = column }
      end
    end
  end
  return candidates
end

function CursorTargets:clear_target()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  self.target = nil
end

function CursorTargets:place_target()
  local candidates = candidates_from(self.position, self.rows, self.columns, self.distance)
  assert(#candidates > 0, "cursor-target drill has no reachable target")
  self.target = candidates[self.random(1, #candidates)]
  vim.api.nvim_buf_set_extmark(self.context.buf, target_namespace, self.target.row - 1, self.target.column - 1, {
    virt_text = { { "X", { highlights.target, "Bold" } } },
    virt_text_pos = "overlay",
    priority = highlights.persistent_priority,
  })
end

function CursorTargets:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d targets"):format(self.rounds)
  end
  if self.phase == "running" then
    return ("Target %d/%d · move with h j k l"):format(self.completed + 1, self.rounds)
  end
  return self.final_status or "Finished"
end

function CursorTargets:reset()
  self:clear_target()
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self.position = {
    row = math.floor((self.rows + 1) / 2),
    column = math.floor((self.columns + 1) / 2),
  }

  local lines = {}
  for _ = 1, self.rows do
    lines[#lines + 1] = string.rep(".", self.columns)
  end

  vim.bo[self.context.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.context.buf, 0, -1, false, lines)
  vim.bo[self.context.buf].modifiable = false
  vim.bo[self.context.buf].modified = false
  vim.api.nvim_win_set_cursor(0, { self.position.row, self.position.column - 1 })
  return self:status()
end

function CursorTargets:start()
  if self.phase == "running" then
    return false
  end
  if self.phase == "finished" then
    self:reset()
  end
  self.position = {
    row = math.floor((self.rows + 1) / 2),
    column = math.floor((self.columns + 1) / 2),
  }
  vim.api.nvim_win_set_cursor(0, { self.position.row, self.position.column - 1 })
  self.completed = 0
  self.started_at = self.clock()
  self.phase = "running"
  self:place_target()
  self.callbacks.status(self:status())
  return true
end

function CursorTargets:on_cursor()
  if self.phase ~= "running" or vim.api.nvim_get_current_buf() ~= self.context.buf then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  if cursor[1] ~= self.target.row or cursor[2] ~= self.target.column - 1 then
    return false
  end

  self.position = { row = self.target.row, column = self.target.column }
  self.completed = self.completed + 1
  self:clear_target()
  if self.completed < self.rounds then
    self:place_target()
    self.callbacks.status(self:status())
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
      optimal_moves = self.rounds * self.distance,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function CursorTargets:on_event()
  return self:on_cursor()
end

function CursorTargets:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function CursorTargets:close()
  if vim.api.nvim_buf_is_valid(self.context.buf) then
    self:clear_target()
  end
end

function M.new(context, specification, callbacks)
  local instance = setmetatable({
    context = context,
    callbacks = callbacks,
    rows = specification.rows,
    columns = specification.columns,
    distance = specification.distance,
    rounds = specification.rounds,
    -- Lua's default PRNG repeats the same sequence in fresh Neovim processes
    -- unless explicitly seeded. Vim's rand() is already seeded per instance.
    random = callbacks.random or pool.default_random,
    clock = callbacks.clock or (vim.uv or vim.loop).hrtime,
  }, CursorTargets)
  return instance
end

M.candidates_from = candidates_from

return M
