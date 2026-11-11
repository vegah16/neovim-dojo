-- Disposable, file-backed projects for tasks with `setup.kind = "project"`.
-- All destructive operations require the exact session root, which is created
-- by the engine and never supplied by input.
--
-- Plugin-specific behaviour (a file manager's buffers, a marked-file list, a
-- Git sign plugin) does not belong here. A configuration adds it with
-- `extend()`; see README.md, "File-backed tasks".
local M = {}
local extensions = {}

-- Add plugin-specific fixture handling. Every field is optional:
--   cleanup(context)         retire what the plugin holds for the fixture
--   observe(context, event)  record what the learner did (context.workspace.seen)
--   check(context, check)    return false when a declared outcome is not met
--   models[name](context, scene)  prepare a scene whose `model` is `name`
-- A second call with the same `name` replaces the first.
function M.extend(extension)
  assert(type(extension) == "table" and type(extension.name) == "string", "a workspace extension needs a name")
  for index, existing in ipairs(extensions) do
    if existing.name == extension.name then
      extensions[index] = extension
      return
    end
  end
  extensions[#extensions + 1] = extension
end
local function inside(context, path)
  return type(path) == "string" and path:sub(1, #context.project_root + 1) == context.project_root .. "/"
end
function M.path(context, relative)
  assert(
    context.project_root and relative ~= "" and not relative:match("^[/\\]") and not relative:find("..", 1, true),
    "unsafe fixture path"
  )
  return context.project_root .. "/" .. relative
end
function M.git(context, ...)
  local command = { "git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", "-C", context.project_root }
  vim.list_extend(command, { ... })
  local result = vim
    .system(command, {
      text = true,
      clear_env = true,
      env = { PATH = vim.env.PATH, LANG = "C", GIT_CONFIG_NOSYSTEM = "1", GIT_CONFIG_GLOBAL = "/dev/null" },
    })
    :wait(5000)
  assert(result.code == 0, result.stderr)
  return result.stdout
end
function M.lines(context, relative, disk)
  local path = M.path(context, relative)
  local buf = vim.fn.bufnr(path)
  if not disk and buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil
end
function M.write(context, relative, lines)
  local path = M.path(context, relative)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  assert(vim.fn.writefile(lines, path) == 0)
end
function M.edit(context, relative)
  local path = M.path(context, relative)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_set_current_buf(buf)
  else
    vim.cmd("hide edit " .. vim.fn.fnameescape(path))
  end
  vim.bo.bufhidden = "hide"
end
-- True for the fixture root itself or any path below it.
function M.owns(context, path)
  return path == context.project_root or inside(context, path)
end
function M.buffers(context)
  return vim.tbl_filter(function(buf)
    return inside(context, vim.api.nvim_buf_get_name(buf))
  end, vim.api.nvim_list_bufs())
end
local fixture_buffers = M.buffers
function M.cleanup(context)
  if not context.workspace then
    return
  end
  if context.workspace.cleanup then
    context.workspace.cleanup(context)
  end
  -- FileType schedules LSP startup. Let already queued callbacks inspect valid
  -- owned buffers before teardown wipes them, then stop clients at this root.
  vim.wait(1, function()
    return false
  end, 1)
  for _, extension in ipairs(extensions) do
    if extension.cleanup then
      extension.cleanup(context)
    end
  end
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.config.root_dir == context.project_root then
      client:stop(true)
    end
  end
  if context.workspace.qf then
    vim.fn.setqflist({}, "r", context.workspace.qf)
  end
  if context.workspace.global_cwd then
    local cwd = vim.fn.getcwd(-1, -1)
    if cwd == context.project_root or inside(context, cwd) then
      vim.api.nvim_cmd({ cmd = "cd", args = { context.workspace.global_cwd } }, {})
    end
  end
  -- Only wholly fixture-owned additional tabs are retired. Mixed or external
  -- views remain the user's responsibility and must never be force-closed.
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if tab ~= context.tab then
      local wins = vim.api.nvim_tabpage_list_wins(tab)
      local owned = #wins > 0
      for _, win in ipairs(wins) do
        owned = owned and inside(context, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)))
      end
      if owned then
        local restore = vim.api.nvim_get_current_tabpage()
        vim.api.nvim_set_current_tabpage(tab)
        vim.cmd("tabclose!")
        if vim.api.nvim_tabpage_is_valid(restore) then
          vim.api.nvim_set_current_tabpage(restore)
        end
      end
    end
  end
  context.workspace = nil
end
function M.prepare(context, scene)
  M.cleanup(context)
  vim.api.nvim_set_current_tabpage(context.tab)
  vim.api.nvim_win_set_buf(0, context.buf)
  vim.cmd("silent! only!")
  for _, buf in ipairs(fixture_buffers(context)) do
    if buf ~= context.buf then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  -- Keep the directory (and owned Git metadata) stable. Plugin watchers cache
  -- repository identity; deleting/recreating .git at the same path strands them.
  local setup = context.lesson.setup
  vim.fn.mkdir(context.project_root, "p")
  vim.cmd.tcd(vim.fn.fnameescape(context.project_root))
  local entries = {}
  for name in vim.fs.dir(context.project_root) do
    entries[#entries + 1] = name
  end
  for _, name in ipairs(entries) do
    if not (setup.git and context.git_initialized and name == ".git") then
      vim.fn.delete(context.project_root .. "/" .. name, "rf")
    end
  end
  local files = vim.tbl_extend("force", setup.files or {}, scene.files or {})
  for relative, lines in pairs(files) do
    M.write(context, relative, lines)
  end
  vim.bo[context.buf].bufhidden = "hide"
  vim.bo[context.buf].modifiable = true
  M.write(context, context.entry_relative, scene.lines)
  vim.api.nvim_buf_call(context.buf, function()
    vim.cmd("silent noautocmd edit! " .. vim.fn.fnameescape(M.path(context, context.entry_relative)))
  end)
  vim.api.nvim_win_set_cursor(0, scene.cursor or { 1, 0 })
  vim.cmd.tcd(vim.fn.fnameescape(context.project_root))
  context.workspace = { seen = {}, global_cwd = vim.fn.getcwd(-1, -1) }
  local model = scene.model or setup.model
  if setup.git then
    if not context.git_initialized then
      M.git(context, "init", "--template=", "--quiet")
      context.git_initialized = true
    end
    M.git(context, "read-tree", "--empty")
    M.git(context, "add", "-A")
    M.git(
      context,
      "-c",
      "user.name=Dojo Fixture",
      "-c",
      "user.email=dojo@example.invalid",
      "commit",
      "--allow-empty",
      "--quiet",
      "-m",
      "Fixture baseline"
    )
  end
  if model == "split" then
    vim.cmd.vsplit()
  elseif model == "qf" then
    context.workspace.qf = vim.fn.getqflist({ items = 0, title = 0, context = 0, idx = 0 })
    local items = {}
    for _, relative in ipairs(scene.results or setup.results or { "alpha.txt", "beta.txt" }) do
      items[#items + 1] = { filename = M.path(context, relative), lnum = 1, col = 1, text = "TODO fixture finding" }
    end
    vim.fn.setqflist({}, "r", { items = items, title = "Dojo fixture findings" })
  elseif model then
    for _, extension in ipairs(extensions) do
      if extension.models and extension.models[model] then
        extension.models[model](context, scene)
      end
    end
  end
  if setup.prepare then
    setup.prepare(context, scene)
  end
  vim.api.nvim_buf_call(context.buf, function()
    vim.cmd("silent edit!")
  end)
  vim.api.nvim_win_set_cursor(0, scene.cursor or { 1, 0 })
  vim.bo[context.buf].filetype = vim.filetype.match({ filename = M.path(context, context.entry_relative) })
    or context.lesson.filetype
    or "text"
  if setup.after_read then
    setup.after_read(context, scene)
  end
end
function M.setup(context, setup)
  M.prepare(context, { lines = context.lesson.lines, cursor = context.lesson.cursor, model = setup.model })
end
function M.observe(context, event)
  if not context.workspace then
    return
  end
  for _, extension in ipairs(extensions) do
    if extension.observe then
      extension.observe(context, event)
    end
  end
  if vim.bo.filetype == "help" then
    context.workspace.seen.help = true
  end
  local name = vim.api.nvim_buf_get_name(0)
  if inside(context, name) then
    vim.bo.bufhidden = "hide"
    context.workspace.seen[name:sub(#context.project_root + 2)] = true
  end
end
function M.check(context, check)
  if not context.workspace then
    return false
  end
  for relative, lines in pairs(check.files or {}) do
    if not vim.deep_equal(M.lines(context, relative, check.disk), lines) then
      return false
    end
  end
  for _, relative in ipairs(check.absent or {}) do
    if vim.uv.fs_stat(M.path(context, relative)) then
      return false
    end
  end
  for _, relative in ipairs(check.dirs or {}) do
    if vim.fn.isdirectory(M.path(context, relative)) ~= 1 then
      return false
    end
  end
  if check.position then
    if vim.api.nvim_buf_get_name(0) ~= M.path(context, check.position.file) then
      return false
    end
    if check.position.cursor and not vim.deep_equal(vim.api.nvim_win_get_cursor(0), check.position.cursor) then
      return false
    end
  end
  for _, relative in ipairs(check.visited or {}) do
    if not context.workspace.seen[relative] then
      return false
    end
  end
  if check.layout then
    local wins = vim.api.nvim_tabpage_list_wins(context.tab)
    if #wins ~= check.layout.count then
      return false
    end
    if check.layout.same_buffer then
      for _, w in ipairs(wins) do
        if vim.api.nvim_win_get_buf(w) ~= context.buf then
          return false
        end
      end
    end
    if check.layout.vertical then
      local row = vim.api.nvim_win_get_position(wins[1])[1]
      for _, w in ipairs(wins) do
        if vim.api.nvim_win_get_position(w)[1] ~= row then
          return false
        end
      end
    end
  end
  if check.tcd then
    if vim.fn.getcwd() ~= M.path(context, check.tcd) or (vim.fn.haslocaldir(-1) ~= 1 or vim.fn.haslocaldir() ~= 0) then
      return false
    end
  end
  for _, extension in ipairs(extensions) do
    if extension.check and extension.check(context, check) == false then
      return false
    end
  end
  if check.extra and not check.extra(context) then
    return false
  end
  return true
end
function M.lesson(id, title, objective, steps, lines, check, setup, options)
  local task = require("neovim_dojo.author").lesson(id, title, objective, steps, lines, check, options)
  task.setup = vim.tbl_extend("force", { kind = "project", entry = "main.txt", files = {} }, setup or {})
  if task.setup.git then
    task.requires = task.requires or {}
    task.requires.capabilities = task.requires.capabilities or {}
    if not vim.tbl_contains(task.requires.capabilities, "git") then
      task.requires.capabilities[#task.requires.capabilities + 1] = "git"
    end
  end
  task.check.kind = check.kind or "workspace"
  return task
end
function M.drill(id, title, objective, steps, scenes, setup, options)
  local task = require("neovim_dojo.author").drill(id, title, objective, steps, scenes, options)
  task.setup = vim.tbl_extend("force", { kind = "project", entry = "main.txt", files = {} }, setup or {})
  if task.setup.git then
    task.requires = task.requires or {}
    task.requires.capabilities = task.requires.capabilities or {}
    if not vim.tbl_contains(task.requires.capabilities, "git") then
      task.requires.capabilities[#task.requires.capabilities + 1] = "git"
    end
  end
  task.drill.prepare, task.drill.check, task.drill.cleanup = M.prepare, M.check, M.cleanup
  task.drill.reset = function(c)
    M.prepare(c, { lines = { "Press Enter to start. Check each completed round with ,k." } })
  end
  return task
end
return M
