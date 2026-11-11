local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")

local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-syntax-target")

local SyntaxNodes = {}
SyntaxNodes.__index = SyntaxNodes

local function fixture_lines(fixture)
  return fixture.lines or { fixture.line }
end

local function target_position(fixture)
  local lines = fixture_lines(fixture)
  local row = (fixture.target_line or 1) - 1
  local line = assert(lines[row + 1], "syntax-node target line is outside its fixture")
  local first = assert(line:find(fixture.target, 1, true)) - 1
  return lines, row, first
end

local function expected_lines(fixture, lines, row, first)
  if fixture.expected_lines then
    return fixture.expected_lines
  end
  if fixture.expected then
    return { fixture.expected }
  end

  local expected = vim.deepcopy(lines)
  local line = expected[row + 1]
  expected[row + 1] = line:sub(1, first) .. line:sub(first + #fixture.target + 1)
  return expected
end

local function set_lines(instance, lines, cursor)
  local buf = instance.context.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
end

function SyntaxNodes:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    return ("Round %d/%d · %s"):format(self.completed + 1, self.rounds, self.specification.prompt)
  end
  return self.final_status or "Finished · press <CR> to replay"
end

function SyntaxNodes:clear_target()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
end

function SyntaxNodes:reset()
  self:clear_target()
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self.schedule = pool.sample(self.specification.fixtures, self.rounds, self.random)
  set_lines(self, { "Press Enter to start this drill." }, { 1, 0 })
  vim.bo[self.context.buf].modifiable = false
  return self:status()
end

function SyntaxNodes:render_round()
  self:clear_target()
  local fixture = self.schedule[self.completed + 1]
  local lines, target_row, target_column = target_position(fixture)
  local cursor_offset = assert(fixture.target:find(fixture.cursor_text or fixture.target, 1, true)) - 1
  self.expected_lines = expected_lines(fixture, lines, target_row, target_column)
  set_lines(self, lines, { target_row + 1, target_column + cursor_offset })
  vim.api.nvim_buf_set_extmark(self.context.buf, target_namespace, target_row, target_column, {
    end_row = target_row,
    end_col = target_column + #fixture.target,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

function SyntaxNodes:start()
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

function SyntaxNodes:on_event(event)
  if
    self.phase ~= "running"
    or event.event ~= "TextChanged"
    or vim.api.nvim_get_current_buf() ~= self.context.buf
    or not vim.deep_equal(vim.api.nvim_buf_get_lines(self.context.buf, 0, -1, false), self.expected_lines)
  then
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
      pool_size = #self.specification.fixtures,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function SyntaxNodes:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function SyntaxNodes:close()
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
    random = callbacks.random or pool.default_random,
    clock = callbacks.clock or (vim.uv or vim.loop).hrtime,
  }, SyntaxNodes)
end

return M
