local M = {}
local pool = require("neovim_dojo.drills.pool")
local highlights = require("neovim_dojo.highlights")

local target_namespace = vim.api.nvim_create_namespace("neovim-dojo.drill-text-target")

local TextActions = {}
TextActions.__index = TextActions

local function set_lines(instance, lines, cursor)
  local buf = instance.context.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
end

local function relative_schedule(instance)
  return pool.schedule({ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, instance.rounds, instance.random)
end

local function render_relative(instance)
  local rows = 25
  local origin = 13
  local offset = instance.schedule[instance.completed + 1]
  local direction = instance.random(1, 2) == 1 and -1 or 1
  local target_row = origin + direction * offset
  local lines = {}
  for row = 1, rows do
    lines[row] = ("practice line %02d"):format(row)
  end
  lines[target_row] = "DELETE THIS LINE"
  instance.expected = { target = "DELETE THIS LINE", rows = rows }
  set_lines(instance, lines, { origin, 0 })
  vim.wo.number = true
  vim.wo.relativenumber = true
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, target_row - 1, 0, {
    end_col = #lines[target_row],
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

local function check_relative(instance, event)
  if event.event ~= "TextChanged" then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(instance.context.buf, 0, -1, false)
  return #lines == instance.expected.rows - 1 and not vim.tbl_contains(lines, instance.expected.target)
end

local word_pairs = {
  { "ember", "orbit" },
  { "harbor", "violet" },
  { "maple", "comet" },
  { "silver", "anchor" },
  { "raven", "coral" },
  { "willow", "signal" },
}

local function odd_word_schedule(instance)
  local positions = pool.schedule({ 1, 2, 3, 4, 5, 6 }, instance.rounds, instance.random)
  local pairs = pool.schedule(word_pairs, instance.rounds, instance.random)
  local result = {}
  for index = 1, instance.rounds do
    result[index] = { position = positions[index], common = pairs[index][1], odd = pairs[index][2] }
  end
  return result
end

local function render_odd_word(instance)
  local fixture = instance.schedule[instance.completed + 1]
  local words = {}
  for index = 1, 6 do
    words[index] = index == fixture.position and fixture.odd or fixture.common
  end
  local line = table.concat(words, " ")
  local first = assert(line:find(fixture.odd, 1, true)) - 1
  instance.expected = fixture
  set_lines(instance, { line }, { 1, 0 })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, first, {
    end_col = first + #fixture.odd,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

local function check_odd_word(instance, event)
  if event.event ~= "TextChanged" then
    return false
  end
  local words = {}
  for word in vim.api.nvim_get_current_line():gmatch("[%a]+") do
    words[#words + 1] = word
  end
  if #words ~= 5 then
    return false
  end
  for _, word in ipairs(words) do
    if word ~= instance.expected.common then
      return false
    end
  end
  return true
end

local function container_schedule(instance)
  return pool.schedule({ "brace", "bracket" }, instance.rounds, instance.random)
end

local function render_container(instance)
  local container = instance.schedule[instance.completed + 1]
  local line = container == "brace" and "local result = { alpha beta gamma }" or "local result = [ alpha, beta, gamma ]"
  local inner = container == "brace" and "alpha beta gamma" or "alpha, beta, gamma"
  instance.expected = container == "brace" and "localresult={dojo}" or "localresult=[dojo]"
  local content = assert(line:find(inner, 1, true))
  set_lines(instance, { line }, { 1, content - 1 })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, content - 1, {
    end_col = content - 1 + #inner,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

local function check_container(instance, event)
  if event.event ~= "InsertLeave" and event.event ~= "TextChanged" then
    return false
  end
  return vim.api.nvim_get_current_line():gsub("%s+", "") == instance.expected
end

local marked_sentence = "Bright foxes jump over calm rivers near silent woods at dawn."
local marked_words = { "Bright", "foxes", "jump", "over", "calm", "rivers", "near", "silent", "woods", "dawn" }

local function marked_schedule(instance)
  local columns = {}
  for _, word in ipairs(marked_words) do
    columns[#columns + 1] = assert(marked_sentence:find(word, 1, true)) - 1
  end
  return pool.schedule(columns, instance.rounds, instance.random)
end

local function toggled_at(text, column)
  local character = text:sub(column + 1, column + 1)
  local toggled = character == character:lower() and character:upper() or character:lower()
  return text:sub(1, column) .. toggled .. text:sub(column + 2)
end

local function render_marked(instance)
  local column = instance.schedule[instance.completed + 1]
  local pointer = string.rep(" ", column) .. "^"
  instance.expected = toggled_at(marked_sentence, column)
  set_lines(instance, { marked_sentence, pointer }, { 1, 0 })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, column, {
    end_col = column + 1,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

local function move_line_schedule(instance)
  local fixtures = {}
  for distance = 1, 5 do
    fixtures[#fixtures + 1] = { direction = "up", distance = distance }
    fixtures[#fixtures + 1] = { direction = "down", distance = distance }
  end
  return pool.schedule(fixtures, instance.rounds, instance.random)
end

local function render_move_line(instance)
  local rows = 13
  local origin = 7
  local fixture = instance.schedule[instance.completed + 1]
  local target = "MOVE THIS LINE"
  local anchor = fixture.direction == "up" and "ANCHOR · place target above this line"
    or "ANCHOR · place target below this line"
  local anchor_row = origin + (fixture.direction == "up" and -fixture.distance or fixture.distance)
  local lines = {}
  for row = 1, rows do
    lines[row] = ("practice line %02d"):format(row)
  end
  lines[origin] = target
  lines[anchor_row] = anchor
  instance.expected = {
    rows = rows,
    target = target,
    anchor = anchor,
    direction = fixture.direction,
    distance = fixture.distance,
  }
  set_lines(instance, lines, { origin, 0 })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, origin - 1, 0, {
    end_col = #target,
    hl_group = highlights.target,
    priority = 200,
  })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, anchor_row - 1, 0, {
    end_col = #anchor,
    hl_group = "DiagnosticInfo",
    priority = 200,
  })
end

local function check_move_line(instance, event)
  -- A mapping that moves a line goes on after the text has changed (`:m`,
  -- then `gv=gv`). Wait until the editor is idle; otherwise the rest of the
  -- mapping runs on the next board and leaves the cursor on its first line.
  if event.event ~= "SafeState" then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(instance.context.buf, 0, -1, false)
  if #lines ~= instance.expected.rows then
    return false
  end
  local target_row
  local anchor_row
  for row, line in ipairs(lines) do
    if line == instance.expected.target then
      target_row = row
    elseif line == instance.expected.anchor then
      anchor_row = row
    end
  end
  if not target_row or not anchor_row then
    return false
  end
  if instance.expected.direction == "up" then
    return target_row + 1 == anchor_row
  end
  return anchor_row + 1 == target_row
end

local function leave_visual_mode(instance)
  vim.schedule(function()
    if
      not vim.api.nvim_buf_is_valid(instance.context.buf) or vim.api.nvim_get_current_buf() ~= instance.context.buf
    then
      return
    end
    local mode = vim.api.nvim_get_mode().mode
    if mode == "v" or mode == "V" or mode == "\22" then
      vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    end
  end)
end

local function check_marked(instance, event)
  return event.event == "TextChanged"
    and vim.api.nvim_buf_get_lines(instance.context.buf, 0, 1, false)[1] == instance.expected
end

local character_motion_characters = { "q", "x", "z", "v", "b", "g" }
local function character_motion_schedule(instance)
  local fixtures = {}
  for _, motion in ipairs({ "f", "F", "t", "T" }) do
    for rank = 2, 4 do
      fixtures[#fixtures + 1] = { motion = motion, rank = rank }
    end
  end
  local schedule = pool.schedule(fixtures, instance.rounds, instance.random)
  local characters = pool.schedule(character_motion_characters, instance.rounds, instance.random)
  for index, fixture in ipairs(schedule) do
    fixture = vim.deepcopy(fixture)
    fixture.character = characters[index]
    schedule[index] = fixture
  end
  return schedule
end

local function render_character_motion(instance)
  local fixture = instance.schedule[instance.completed + 1]
  local origin = 24
  local positions = {
    left = { 19, 14, 9, 4 },
    right = { 29, 34, 39, 44 },
  }
  local columns = fixture.motion:match("[FT]") and positions.left or positions.right
  local target_column = columns[fixture.rank]
  local landing_column = target_column
  if fixture.motion == "t" then
    landing_column = target_column - 1
  elseif fixture.motion == "T" then
    landing_column = target_column + 1
  end

  local line = string.rep(".", 49)
  for _, column in ipairs(positions.left) do
    line = line:sub(1, column) .. fixture.character .. line:sub(column + 2)
  end
  for _, column in ipairs(positions.right) do
    line = line:sub(1, column) .. fixture.character .. line:sub(column + 2)
  end
  line = line:sub(1, origin) .. "|" .. line:sub(origin + 2)

  instance.expected = {
    motion = fixture.motion,
    character = fixture.character,
    target_column = target_column,
    landing_column = landing_column,
  }
  set_lines(instance, { line, string.rep(" ", landing_column) .. "^" }, { 1, origin })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, target_column, {
    end_col = target_column + 1,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, origin, {
    end_col = origin + 1,
    hl_group = "DiagnosticInfo",
    priority = 200,
  })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 1, landing_column, {
    end_col = landing_column + 1,
    hl_group = "DiagnosticInfo",
    priority = highlights.persistent_priority,
  })
end

local function check_character_motion(instance, event)
  if event.event ~= "CursorMoved" then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] == 1 and cursor[2] == instance.expected.landing_column
end

local function character_motion_prompt(instance)
  local expected = instance.expected
  if not expected then
    return "repeat the requested character motion to the yellow target"
  end
  -- The key that repeats a motion depends on the editor: natively `;`, with
  -- a plugin often the motion key itself or its lowercase form.
  local again = (instance.specification.repeat_keys or {})[expected.motion] or expected.motion
  return ("use %s{char}, then repeat %s to reach the yellow target"):format(expected.motion, again)
end

local function dismiss_character_motion_overlay()
  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end)
end

local function register_schedule(instance)
  instance.tokens = pool.sample(instance.specification.words, instance.rounds, instance.random)
  return pool.schedule(instance.specification.registers, instance.rounds, instance.random)
end

local function render_register(instance)
  instance.expected = {
    register = instance.schedule[instance.completed + 1],
    token = instance.tokens[instance.completed + 1],
  }
  instance.saved_token, instance.deleted_noise = false, false
  vim.fn.setreg(instance.expected.register, "")
  set_lines(instance, { "token = " .. instance.expected.token, "discard = spare", "recalled = none" }, { 1, 8 })
  vim.api.nvim_buf_set_extmark(instance.context.buf, target_namespace, 0, 8, {
    end_col = 8 + #instance.expected.token,
    hl_group = highlights.target,
    priority = highlights.persistent_priority,
  })
end

local function check_register(instance, event)
  local expected = instance.expected
  if event.event == "TextYankPost" then
    local action = vim.v.event
    if
      action.operator == "y"
      and (action.regname or ""):lower() == expected.register
      and vim.fn.getreg(expected.register) == expected.token
    then
      instance.saved_token = true
    elseif action.operator == "d" and action.regcontents[1] == "discard = spare" then
      instance.deleted_noise = true
    end
  end
  return instance.saved_token
    and instance.deleted_noise
    and vim.fn.getreg(expected.register) == expected.token
    and vim.deep_equal(vim.api.nvim_buf_get_lines(instance.context.buf, 0, -1, false), {
      "token = " .. expected.token,
      "recalled = " .. expected.token,
    })
end

local function macro_schedule(instance)
  local rows = instance.specification.rows
  local words = pool.sample(instance.specification.words, instance.rounds * rows, instance.random)
  local schedule = {}
  for round = 1, instance.rounds do
    schedule[round] = {}
    for row = 1, rows do
      schedule[round][row] = words[(round - 1) * rows + row]
    end
  end
  return schedule
end

local function render_macro(instance)
  local lines = {}
  instance.expected_lines = {}
  instance.recorded = false
  vim.fn.setreg(instance.specification.register, "")
  for _, word in ipairs(instance.schedule[instance.completed + 1]) do
    lines[#lines + 1] = "item: " .. word
    instance.expected_lines[#instance.expected_lines + 1] = "- " .. word:upper()
  end
  -- The recording ends with j0. Give its last replay a real landing row so
  -- an EOF motion cannot abort the macro before execution has unwound.
  lines[#lines + 1] = "STOP"
  instance.expected_lines[#instance.expected_lines + 1] = "STOP"
  set_lines(instance, lines, { 1, 0 })
end

local function check_macro(instance, event)
  if event.event == "RecordingLeave" then
    if (vim.v.event.regname or ""):lower() == instance.specification.register and vim.v.event.regcontents ~= "" then
      instance.recorded = true
    end
    -- reg_recording() and the register contents are updated after this event.
    vim.schedule(function()
      instance:on_event({ event = "TextChanged" })
    end)
    return false
  end
  -- SafeState is Neovim's explicit idle boundary, including after a counted
  -- replay. Do not replace the board while tail motions are still executing.
  local idle = event.event == "SafeState" or vim.fn.reg_executing() == ""
  return instance.recorded
    and vim.fn.reg_recording() == ""
    and idle
    and vim.fn.getreg(instance.specification.register) ~= ""
    and vim.deep_equal(vim.api.nvim_buf_get_lines(instance.context.buf, 0, -1, false), instance.expected_lines)
end

local variants = {
  macro_lines = {
    prompt = function(instance)
      return ("record in %s, normalize %d rows to uppercase bullets"):format(
        instance.specification.register,
        instance.specification.rows
      )
    end,
    schedule = macro_schedule,
    render = render_macro,
    check = check_macro,
  },
  register_recall = {
    prompt = function(instance)
      return "save in register " .. instance.expected.register .. ", delete discard, then recall"
    end,
    schedule = register_schedule,
    render = render_register,
    check = check_register,
  },
  relative_line = {
    prompt = "jump by relative count, then delete the target line",
    schedule = relative_schedule,
    render = render_relative,
    check = check_relative,
  },
  odd_word = {
    prompt = "reach and delete the highlighted word with w and dw",
    schedule = odd_word_schedule,
    render = render_odd_word,
    check = check_odd_word,
  },
  change_inside = {
    prompt = "replace inside the container with dojo",
    schedule = container_schedule,
    render = render_container,
    check = check_container,
  },
  marked_case = {
    prompt = "reach the highlighted character and toggle its case with ~",
    schedule = marked_schedule,
    render = render_marked,
    check = check_marked,
  },
  move_visual_line = {
    prompt = "move the yellow line to the side requested by the blue anchor with visual J/K",
    schedule = move_line_schedule,
    render = render_move_line,
    check = check_move_line,
    after_success = leave_visual_mode,
  },
  character_motion = {
    prompt = character_motion_prompt,
    schedule = character_motion_schedule,
    render = render_character_motion,
    check = check_character_motion,
    after_success = dismiss_character_motion_overlay,
  },
}

function TextActions:clear_target()
  vim.api.nvim_buf_clear_namespace(self.context.buf, target_namespace, 0, -1)
end

function TextActions:status()
  if self.phase == "ready" then
    return ("Ready · press <CR> to start · %d rounds"):format(self.rounds)
  end
  if self.phase == "running" then
    local prompt = type(self.definition.prompt) == "function" and self.definition.prompt(self) or self.definition.prompt
    return ("Round %d/%d · %s"):format(self.completed + 1, self.rounds, prompt)
  end
  return self.final_status or "Finished"
end

function TextActions:reset()
  self:clear_target()
  self.phase = "ready"
  self.completed = 0
  self.started_at = nil
  self.final_status = nil
  self.schedule = self.definition.schedule(self)
  set_lines(self, { "Press Enter to start this drill." }, { 1, 0 })
  vim.bo[self.context.buf].modifiable = false
  return self:status()
end

function TextActions:render_round()
  self:clear_target()
  vim.bo[self.context.buf].modifiable = true
  self.definition.render(self)
  vim.bo[self.context.buf].modified = false
end

function TextActions:start()
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

function TextActions:on_event(event)
  if self.phase ~= "running" or vim.api.nvim_get_current_buf() ~= self.context.buf then
    return false
  end
  if not self.definition.check(self, event) then
    return false
  end

  if self.definition.after_success then
    self.definition.after_success(self)
  end

  self.completed = self.completed + 1
  if self.completed < self.rounds then
    self:render_round()
    self.callbacks.status(self:status(), true)
    return true
  end

  self:clear_target()
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
      rows = self.specification.rows,
    },
  }, function(status)
    self.final_status = status
  end)
  return true
end

function TextActions:apply_mappings()
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = self.context.buf, desc = "Start or replay Dojo drill" })
end

function TextActions:close()
  if vim.api.nvim_buf_is_valid(self.context.buf) then
    self:clear_target()
  end
end

function M.new(context, specification, callbacks)
  local definition = assert(variants[specification.variant], "unknown text-action drill variant")
  return setmetatable({
    context = context,
    specification = specification,
    callbacks = callbacks,
    definition = definition,
    rounds = specification.rounds,
    random = callbacks.random or pool.default_random,
    clock = callbacks.clock or (vim.uv or vim.loop).hrtime,
  }, TextActions)
end

M.variants = variants

return M
