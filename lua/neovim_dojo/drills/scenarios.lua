-- Untimed by default: a balanced set of complete outcomes, checked explicitly.
-- Explicit checking prevents mid-command board replacement and gives users time
-- to inspect their work. Curriculum callbacks can own plugin-backed fixtures.
local pool = require("neovim_dojo.drills.pool")
local outcomes = require("neovim_dojo.outcomes")
local controls = require("neovim_dojo.controls")
local M = {}
local Runner = {}
Runner.__index = Runner

function Runner:status()
  if self.phase == "ready" then
    return "Ready · <CR> start · ,r reset · ,q quit"
  end
  if self.phase == "finished" then
    return self.final_status or "Finished · <CR> replay"
  end
  return ("Round %d/%d · %s · ,k check"):format(self.completed + 1, #self.schedule, self.scene.goal)
end

function Runner:reset()
  if self.specification.cleanup then
    self.specification.cleanup(self.context)
  end
  if self.specification.reset then
    self.specification.reset(self.context)
  end
  self.phase, self.completed, self.final_status = "ready", 0, nil
  -- Sample without replacement: a pool larger than the run must not always
  -- present its first scenes.
  self.schedule = pool.sample(self.specification.scenes, self.specification.rounds, self.random)
  vim.bo[self.context.buf].modifiable = true
  vim.api.nvim_buf_set_lines(
    self.context.buf,
    0,
    -1,
    false,
    { controls.text("Press Enter to start. Check each completed round with ,k.") }
  )
  vim.bo[self.context.buf].modified = false
  return self:status()
end

function Runner:render_round()
  self.scene = self.schedule[self.completed + 1]
  local context = self.context
  context.scene = self.scene
  if self.specification.prepare then
    self.specification.prepare(context, self.scene)
  else
    vim.api.nvim_win_set_buf(0, context.buf)
    vim.bo[context.buf].modifiable = true
    vim.api.nvim_buf_set_lines(context.buf, 0, -1, false, self.scene.lines)
    vim.bo[context.buf].modified = false
    vim.api.nvim_win_set_cursor(0, self.scene.cursor or { 1, 0 })
  end
  self.callbacks.status(self:status(), true)
end

function Runner:start()
  if self.phase == "running" then
    return
  end
  if self.phase == "finished" then
    self:reset()
  end
  self.phase, self.completed = "running", 0
  self:render_round()
end

function Runner:check()
  if self.phase ~= "running" then
    return false
  end
  local checker = self.specification.check or outcomes.matches
  if not checker(self.context, self.scene.check) then
    self.callbacks.status(self:status() .. " · outcome not reached; inspect or ,h", true)
    return false
  end
  self.completed = self.completed + 1
  if self.completed < #self.schedule then
    self:render_round()
  else
    self.phase = "finished"
    -- A workload count records practice without rewarding speed on integrations.
    self.callbacks.complete({
      metric = "rounds",
      unit = "rounds",
      value = self.completed,
      lower_is_better = false,
      details = { rounds = self.completed, untimed = true },
    }, function(status)
      self.final_status = status
    end)
  end
  return true
end

function Runner:on_event()
  return false
end
function Runner:apply_mappings(buf)
  vim.keymap.set("n", "<CR>", function()
    self:start()
  end, { buffer = buf, desc = "Start or replay Dojo drill" })
  vim.keymap.set("n", controls.lhs("k"), function()
    self:check()
  end, { buffer = buf, desc = "Check Dojo round" })
end
function Runner:close()
  if self.specification.cleanup then
    self.specification.cleanup(self.context)
  end
end
function M.new(context, specification, callbacks)
  return setmetatable({
    context = context,
    specification = specification,
    callbacks = callbacks,
    random = callbacks.random or pool.default_random,
  }, Runner)
end
return M
