local M = {}

local registry = require("neovim_dojo.registry")
local session = require("neovim_dojo.session")
local highlights = require("neovim_dojo.highlights")
local controls = require("neovim_dojo.controls")
local workspace = require("neovim_dojo.workspace")
local ideas = require("neovim_dojo.ideas")
local setup_done = false

local defaults = {
  -- Curriculum tables, or the name of a built-in pack.
  curricula = { "native" },
  -- Prefix of the control keys inside a task and in the picker.
  prefix = ",",
  -- Named requirement tests. Git fixtures of file-backed tasks need `git`.
  capabilities = {
    git = function()
      return vim.fn.executable("git") == 1
    end,
  },
  mappings = {},
}

local function curriculum(entry)
  if type(entry) == "string" then
    local ok, pack = pcall(require, "neovim_dojo.packs." .. entry)
    assert(ok, "unknown built-in Neovim Dojo pack: " .. entry)
    return pack
  end
  return entry
end

-- File-backed tasks are built in. Configured hooks run while the fixture
-- still exists; a configured `project` setup or `workspace` checker wins.
local function with_workspace(options)
  options.setups = vim.tbl_extend("keep", options.setups or {}, { project = workspace.setup })
  options.checkers = vim.tbl_extend("keep", options.checkers or {}, { workspace = workspace.check })
  local before_reset, before_quit, on_event = options.before_reset, options.before_quit, options.on_event
  options.before_reset = function(context)
    if before_reset then
      before_reset(context)
    end
    workspace.cleanup(context)
  end
  options.before_quit = function(context)
    if before_quit then
      before_quit(context)
    end
    workspace.cleanup(context)
  end
  options.on_event = function(context, event)
    workspace.observe(context, event)
    if on_event then
      on_event(context, event)
    end
  end
  return options
end

local function command_completion()
  return vim.tbl_map(function(lesson)
    return lesson.id
  end, registry.lessons())
end

function M.register(entry)
  registry.register(curriculum(entry))
  registry.validate_paths()
  session.configure(session.options)
end

function M.setup(options)
  highlights.setup()
  -- Curricula are registered as given; only the other options are merged.
  local given = vim.tbl_extend("force", {}, options or {})
  local curricula = given.curricula or defaults.curricula
  given.curricula = nil
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), given)
  options.curricula = curricula
  controls.set(options.prefix)
  registry.reset()
  for _, entry in ipairs(curricula) do
    registry.register(curriculum(entry))
  end
  registry.validate_paths()
  if options.ideas_path and not options.add_idea then
    options.add_idea = function(idea)
      return ideas.add(options.ideas_path, idea)
    end
  end
  session.configure(with_workspace(options))

  if setup_done then
    return M
  end
  setup_done = true

  vim.api.nvim_create_user_command("NeovimDojo", function(command)
    if command.args ~= "" then
      local lesson = registry.get(command.args)
      if not lesson then
        vim.notify("Unknown Neovim Dojo task: " .. command.args, vim.log.levels.ERROR, { title = "Neovim Dojo" })
        return
      end
      session.start(lesson.id)
      return
    end
    session.open()
  end, { nargs = "?", complete = command_completion, desc = "Open Neovim Dojo" })

  vim.api.nvim_create_user_command("NeovimDojoReset", function(command)
    session.clear_progress(command.bang)
  end, { bang = true, desc = "Reset local Neovim Dojo state" })

  vim.api.nvim_create_user_command("NeovimDojoIdea", function(command)
    local function record(title)
      local ok = session.add_idea({ title = title })
      vim.notify(
        ok and "Dojo idea recorded" or "Could not record Dojo idea",
        ok and vim.log.levels.INFO or vim.log.levels.ERROR,
        {
          title = "Neovim Dojo",
        }
      )
    end
    local title = vim.trim(command.args)
    if title == "" then
      vim.ui.input({ prompt = "Dojo idea: " }, function(value)
        if value and vim.trim(value) ~= "" then
          record(vim.trim(value))
        end
      end)
    else
      record(title)
    end
  end, { nargs = "*", desc = "Record a Neovim Dojo task idea" })

  vim.api.nvim_create_user_command("NeovimDojoIdeas", function()
    if not options.ideas_path then
      vim.notify("No Neovim Dojo idea file is configured", vim.log.levels.WARN, { title = "Neovim Dojo" })
      return
    end
    vim.cmd.edit(vim.fn.fnameescape(options.ideas_path))
  end, { desc = "Open Neovim Dojo task ideas" })

  if options.mappings.open then
    vim.keymap.set("n", options.mappings.open, session.open, { desc = "Open Neovim Dojo" })
  end
  if options.mappings.reset then
    vim.keymap.set("n", options.mappings.reset, function()
      session.clear_progress(false)
    end, { desc = "Reset Neovim Dojo" })
  end
  if options.mappings.idea then
    vim.keymap.set("n", options.mappings.idea, ":NeovimDojoIdea ", { desc = "Record Neovim Dojo idea" })
  end
  return M
end

M.session = session
M.registry = registry

return M
