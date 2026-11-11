local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")
local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-highlighted-target")

local SearchTargets = {}
SearchTargets.__index = SearchTargets

local function set_lines(instance, lines, cursor)
  local buf = instance.context.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
end

function SearchTargets:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    local prompt
    if self.choice_sets then
      local choice = self.choice_sets[self.completed + 1]
      prompt = self.specification.prompt:format(choice.query, choice.target)
    else
      prompt = self.specification.prompt:format(self.targets[self.completed + 1])
    end
    return ("Round %d/%d · %s"):format(self.completed + 1, self.rounds, prompt)
  end
  return self.final_status or "Finished"
end

function SearchTargets:build_schedule()
  if self.specification.choice_sets then
    self.choice_sets = pool.sample(self.specification.choice_sets, self.rounds, self.random)
    local match_count = #self.choice_sets[1].matches
    self.distractors = pool.sample(self.specification.distractors, self.rounds * (self.rows - match_count), self.random)
    return
  end
  self.targets = pool.sample(self.specification.targets, self.rounds, self.random)
  self.target_rows = pool.schedule(vim.fn.range(2, self.rows), self.rounds, self.random)
  self.templates = pool.sample(self.specification.templates, self.rounds, self.random)
  self.distractors = pool.sample(self.specification.distractors, self.rounds * (self.rows - 1), self.random)
end

function SearchTargets:reset()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self:build_schedule()
  set_lines(self, { "Press Enter to start this drill." }, { 1, 0 })
  return self:status()
end

function SearchTargets:set_expected(lines, target)
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
  for row, line in ipairs(lines) do
    local target_start = line:find(target, 1, true)
    if target_start then
      self.expected = {
        row = row,
        first_column = target_start - 1,
        last_column = target_start + #target - 2,
      }
      vim.api.nvim_buf_set_extmark(self.context.buf, target_namespace, row - 1, target_start - 1, {
        end_col = target_start + #target - 1,
        hl_group = highlights.target,
        priority = highlights.persistent_priority,
      })
      return
    end
  end
  error("search-target board must contain its target")
end

function SearchTargets:render_generated_round()
  local round = self.completed + 1
  local target = self.targets[round]
  local target_row = self.target_rows[round]
  local target_line = self.templates[round]:format(target)
  local distractor_offset = self.completed * (self.rows - 1)
  local lines = {}
  local next_distractor = 1

  for row = 1, self.rows do
    if row == target_row then
      lines[row] = target_line
    else
      lines[row] = self.distractors[distractor_offset + next_distractor]
      next_distractor = next_distractor + 1
    end
  end

  set_lines(self, lines, { 1, 0 })
  self:set_expected(lines, target)
end

function SearchTargets:render_choice_round()
  local choice = self.choice_sets[self.completed + 1]
  local words = pool.shuffle(choice.matches, self.random)
  local templates = pool.sample(self.specification.templates, #words, self.random)
  local distractor_count = self.rows - #words
  local distractor_offset = self.completed * distractor_count
  local lines = {}

  for index, word in ipairs(words) do
    lines[#lines + 1] = templates[index]:format(word)
  end
  for index = 1, distractor_count do
    lines[#lines + 1] = self.distractors[distractor_offset + index]
  end
  lines = pool.shuffle(lines, self.random)

  set_lines(self, lines, { 1, 0 })
  self:set_expected(lines, choice.target)
end

function SearchTargets:render_round()
  if self.choice_sets then
    self:render_choice_round()
  else
    self:render_generated_round()
  end
end

function SearchTargets:start()
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

function SearchTargets:on_event(event)
  if self.phase ~= "running" or event.event ~= "CursorMoved" or vim.api.nvim_get_current_buf() ~= self.context.buf then
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
      pool_size = #(self.specification.choice_sets or self.specification.targets),
      matches_per_round = self.choice_sets and #self.choice_sets[1].matches or nil,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function SearchTargets:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function SearchTargets:close()
  if vim.api.nvim_buf_is_valid(self.context.buf) then
    vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
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
  }, SearchTargets)
end

return M
