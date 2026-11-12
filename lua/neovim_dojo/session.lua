-- Active-session runtime for Neovim Dojo. Public setup and curriculum registration
-- live in neovim_dojo/init.lua; this module owns only active-session behavior.
local M = {}

local registry = require("neovim_dojo.registry")
local state = require("neovim_dojo.state")
local drills = require("neovim_dojo.drills")
local highlights = require("neovim_dojo.highlights")
local controls = require("neovim_dojo.controls")
local undo_branches = require("neovim_dojo.drills.undo_branches")

M.catalog = registry.topics()
M.options = {}

local session_group = "NeovimDojoSession"
local instruction_namespace = vim.api.nvim_create_namespace("neovim-dojo.instructions")
local cue_namespace = vim.api.nvim_create_namespace("neovim-dojo.task-cues")
local current
-- Every disposable project root created in this editor session, kept after its
-- task ends so integrations can still recognize a retired fixture's buffers.
local fixture_roots = {}

local function find_topic(id)
  return registry.topic(id)
end

local function cursor_on_text(context, position)
  if vim.api.nvim_get_current_buf() ~= context.buf then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local target_line = context.exercise_start + position.line - 1
  if cursor[1] ~= target_line then
    return false
  end
  local line = vim.api.nvim_get_current_line()
  local start_column = line:find(position.text, 1, true)
  if not start_column then
    return false
  end
  local column = cursor[2] + 1
  return column >= start_column and column < start_column + #position.text
end

-- True for a path inside any disposable project this session has created.
function M.owns_path(path)
  if type(path) ~= "string" then
    return false
  end
  for root in pairs(fixture_roots) do
    if path == root or path:sub(1, #root + 1) == root .. "/" then
      return true
    end
  end
  return false
end

function M.state_path()
  return state.path()
end

function M.progress()
  local result = { passed = {} }
  for id, item in pairs(state.load().lessons) do
    if state.is_completed(item) then
      result.passed[id] = {
        count = item.passes or 0,
        last_practised = item.last_practised,
      }
    end
  end
  return result
end

local function record_pass(lesson)
  if not state.record_pass(lesson) then
    vim.notify("Could not save Neovim Dojo progress", vim.log.levels.ERROR, { title = "Neovim Dojo" })
  end
end

function M.review_status(lesson)
  return state.review_status(lesson)
end

function M.verify(lesson)
  if state.review_status(lesson) == "verified" then
    return state.clear_review(lesson)
  end
  return state.set_review(lesson, "verified")
end

function M.report_issue(lesson, note)
  return state.set_review(lesson, "issue", note)
end

function M.clear_review(lesson)
  return state.clear_review(lesson)
end

-- A required plugin is named like its directory (`flash.nvim`). lazy.nvim
-- knows plugins it has not loaded yet; other managers put them on the
-- runtime path or in a package directory.
local function plugin_installed(name)
  local ok, lazy = pcall(require, "lazy.core.config")
  if ok and lazy.plugins and lazy.plugins[name] then
    return true
  end
  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    if vim.fs.basename(path) == name then
      return true
    end
  end
  return #vim.fn.globpath(vim.o.packpath, "pack/*/*/" .. name, false, true) > 0
end

function M.availability(lesson)
  local missing = {}
  local checker = M.options.requirements
  if checker then
    return checker(lesson)
  end
  for _, plugin in ipairs((lesson.requires or {}).plugins or {}) do
    if not plugin_installed(plugin) then
      missing[#missing + 1] = "plugin:" .. plugin
    end
  end
  for _, parser in ipairs((lesson.requires or {}).parsers or {}) do
    local ok, loaded = pcall(vim.treesitter.language.add, parser)
    if not ok or not loaded then
      missing[#missing + 1] = "parser:" .. parser
    end
  end
  for _, capability in ipairs((lesson.requires or {}).capabilities or {}) do
    local available = M.options.capabilities and M.options.capabilities[capability]
    if not available or not available() then
      missing[#missing + 1] = "capability:" .. capability
    end
  end
  return #missing == 0, missing
end

function M.lesson_state(lesson)
  local dojo_state = state.load()
  local item = dojo_state.lessons[lesson.id] or {}
  local available, missing = M.availability(lesson)
  return {
    passes = item.passes or 0,
    attempts = item.attempts or 0,
    completed = state.is_completed(item),
    review = state.review_status(lesson, dojo_state),
    review_note = item.review and item.review.note or nil,
    reviewed_at = item.review and item.review.at or nil,
    reviewed_revision = item.review and item.review.revision or nil,
    drill = vim.deepcopy(item.drill),
    favorite = state.is_favorite(lesson, dojo_state),
    available = available,
    missing = missing,
  }
end

function M.toggle_favorite(lesson)
  return state.toggle_favorite(lesson)
end

function M.add_idea(idea)
  if M.options.add_idea then
    return M.options.add_idea(idea)
  end
  return state.add_idea(idea)
end

function M.ideas_path()
  return M.options.ideas_path
end

function M.idea_lines()
  local path = M.ideas_path()
  if not path or vim.fn.filereadable(path) ~= 1 then
    return { "# Task ideas", "", "No ideas have been recorded yet." }
  end
  return vim.fn.readfile(path)
end

function M.configure(options)
  M.options = options or {}
  M.catalog = registry.topics()
end

function M.lessons()
  return registry.lessons()
end

function M.topics()
  return registry.topics()
end

function M.paths()
  return registry.paths()
end

function M.find_topic(id)
  return find_topic(id)
end

function M.find_lesson(id)
  return registry.get(id)
end

function M.find_path(id)
  return registry.path(id)
end

function M.path_progress(path_or_id)
  local path = type(path_or_id) == "table" and path_or_id or registry.path(path_or_id)
  if not path then
    return nil
  end
  local dojo_state = state.load()
  local completed = 0
  for _, exercise_id in ipairs(path.entries) do
    if state.is_completed(dojo_state.lessons[exercise_id]) then
      completed = completed + 1
    end
  end
  return {
    completed = completed,
    total = #path.entries,
  }
end

local function path_entry_position(path, exercise_id)
  for position, entry_id in ipairs(path.entries) do
    if entry_id == exercise_id then
      return position
    end
  end
end

local function filtered_path_for(exercise_id)
  local filters = state.filters() or {}
  local path = filters.path and registry.path(filters.path) or nil
  local position = path and path_entry_position(path, exercise_id) or nil
  return position and path or nil, position
end

function M.next_path_entry(path_or_id, after_id)
  local path = type(path_or_id) == "table" and path_or_id or registry.path(path_or_id)
  if not path then
    return nil, "unknown_path"
  end
  local first = 1
  if after_id then
    local position = path_entry_position(path, after_id)
    if not position then
      return nil, "entry_not_in_path"
    end
    first = position + 1
  end
  local dojo_state = state.load()
  for position = first, #path.entries do
    local exercise_id = path.entries[position]
    if not state.is_completed(dojo_state.lessons[exercise_id]) then
      local task = registry.get(exercise_id)
      local available, missing = M.availability(task)
      return {
        path = path,
        task = task,
        position = position,
        available = available,
        missing = missing,
      }
    end
  end
  return nil, "no_incomplete_entry"
end

function M.start_next_path_entry(path_or_id, options)
  local context = current
  local path = type(path_or_id) == "table" and path_or_id
    or (path_or_id and registry.path(path_or_id))
    or (context and context.path)
  if not path then
    local filters = state.filters() or {}
    path = filters.path and registry.path(filters.path) or nil
  end
  if not path then
    vim.notify("Choose a learning path before resuming", vim.log.levels.WARN, { title = "Neovim Dojo" })
    return false, "no_active_path"
  end
  local after_id
  if not (options and options.from_start) and context and context.path and context.path.id == path.id then
    if not M.lesson_state(context.lesson).completed then
      vim.notify(
        "Complete or mark the current task complete before advancing",
        vim.log.levels.WARN,
        { title = path.title }
      )
      return false, "current_incomplete"
    end
    after_id = context.lesson.id
  end
  local entry, reason = M.next_path_entry(path, after_id)
  if not entry then
    local progress = M.path_progress(path)
    local complete = progress.completed == progress.total
    local message = complete
        and controls.text("Path complete: " .. path.title .. ". Use ,M and choose incomplete to restart it.")
      or ("No incomplete entries remain after the current task in " .. path.title)
    vim.notify(message, complete and vim.log.levels.WARN or vim.log.levels.INFO, { title = "Neovim Dojo" })
    return false, reason
  end
  if not entry.available then
    vim.notify(
      ("Next path entry unavailable: %s (%s)"):format(entry.task.title, table.concat(entry.missing, ", ")),
      vim.log.levels.WARN,
      { title = path.title }
    )
    return false, "unavailable"
  end
  M.start(entry.task.id, path.id)
  return true, entry
end

local function normalized(path)
  local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local uv = vim.uv or vim.loop

  -- macOS exposes /var through /private/var. Buffers use the canonical path,
  -- while tempname() may return the shorter alias, so compare real paths when
  -- the file or directory already exists. The second value says whether it
  -- did.
  local real = uv.fs_realpath(absolute)
  return real or absolute, real ~= nil
end

-- Every event of a session asks this for the current buffer, so the answer is
-- remembered per buffer name. Resolving a path walks its directories on disk,
-- which is slow on a network file system. Only an absolute name of an existing
-- file is remembered: any other name resolves against the working directory,
-- or may resolve differently once the file exists.
local function project_relative_path(context, buf)
  if not context.project_root or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local raw = vim.api.nvim_buf_get_name(buf)
  local cache = context.relative_paths
  local cached = cache and cache[buf]
  if cached and cached.name == raw then
    return cached.relative or nil
  end
  local name, exists = normalized(raw)
  -- The root was resolved when the session created it.
  local prefix = context.project_root .. "/"
  local relative = name:sub(1, #prefix) == prefix and name:sub(#prefix + 1) or nil
  if cache and exists and raw:sub(1, 1) == "/" then
    cache[buf] = { name = raw, relative = relative or false }
  end
  return relative
end

local function project_position(context, position)
  local relative = project_relative_path(context, vim.api.nvim_get_current_buf())
  if relative ~= position.file then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_number = position.line
  if relative == context.entry_relative then
    line_number = line_number + context.exercise_start - 1
  end
  if cursor[1] ~= line_number then
    return false
  end
  local line = vim.api.nvim_get_current_line()
  local start_column = line:find(position.text, 1, true)
  if not start_column then
    return false
  end
  local column = cursor[2] + 1
  return column >= start_column and column < start_column + #position.text
end

local function project_file_lines(context, relative)
  local path = normalized(context.project_root .. "/" .. relative)
  local buffer = vim.fn.bufnr(path)
  if buffer ~= -1 and vim.api.nvim_buf_is_loaded(buffer) then
    return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  end
  return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
end

-- Leave room for the number/sign columns in an 80-column terminal. Virtual
-- lines do not use 'wrap', so text beyond the window edge would disappear.
local instruction_width = 72

local instruction_prefix = "│"

local function instruction_words(text)
  local words = {}
  local position = 1
  while position <= #text do
    local first = text:find("%S", position)
    if not first then
      break
    end
    local last
    if text:sub(first, first) == "`" then
      local closing = text:find("`", first + 1, true)
      local following_space = closing and text:find("%s", closing + 1)
      last = following_space and following_space - 1 or #text
    else
      local following_space = text:find("%s", first)
      last = following_space and following_space - 1 or #text
    end
    words[#words + 1] = text:sub(first, last)
    position = last + 1
  end
  return words
end

local function without_instruction_markup(text)
  return (text:gsub("`([^`]+)`", "%1"))
end

local function append_wrapped_instruction(lines, lead, text, continuation_lead)
  text = controls.text(text)
  lead = lead or ""
  continuation_lead = continuation_lead or lead
  local words = instruction_words(text)
  local current_lead = lead
  local current = {}

  local function flush()
    if #current > 0 then
      lines[#lines + 1] = instruction_prefix .. " " .. current_lead .. table.concat(current, " ")
      current = {}
      current_lead = continuation_lead
    end
  end

  for _, word in ipairs(words) do
    local candidate = table.concat(vim.list_extend(vim.deepcopy(current), { word }), " ")
    local width =
      vim.fn.strdisplaywidth(without_instruction_markup(instruction_prefix .. " " .. current_lead .. candidate))
    if #current > 0 and width > instruction_width then
      flush()
    end
    current[#current + 1] = word
  end
  flush()
end

local function instruction_lines(context, status)
  local width = 80
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(context.tab)) do
    if vim.api.nvim_win_get_buf(win) == context.buf then
      width = math.min(width, vim.api.nvim_win_get_width(win))
    end
  end
  instruction_width = math.max(24, math.min(72, width - 8))
  local function instruction(text)
    return text == "" and instruction_prefix or (instruction_prefix .. " " .. text)
  end

  if context.drill_active then
    local compact = { instruction("STATUS") }
    append_wrapped_instruction(compact, "  ", status or "In progress")
    local check = context.lesson.drill.kind == "scenarios" and "`,k` check · " or ""
    append_wrapped_instruction(compact, "  ", check .. "`,h` instructions · `,r` abort/reset · `,q` quit")
    compact[#compact + 1] = instruction("─ EXERCISE ─")
    return compact, 1
  end

  local item = M.lesson_state(context.lesson)
  local lines = {}
  append_wrapped_instruction(lines, "", "NEOVIM DOJO")
  append_wrapped_instruction(
    lines,
    "",
    (context.lesson.kind == "drill" and "DRILL · " or "LESSON · ") .. context.lesson.title
  )
  append_wrapped_instruction(lines, "", "TOPICS · " .. table.concat(context.lesson.topics, ", "))
  if context.path then
    append_wrapped_instruction(
      lines,
      "",
      ("PATH · %s · entry %d/%d"):format(context.path.title, context.path_position, #context.path.entries)
    )
  end
  if item.review_note and item.review_note ~= "" then
    local heading = item.review == "issue" and "REPORTED ISSUE" or "PREVIOUS REVIEW NOTE"
    vim.list_extend(lines, { instruction(""), instruction(heading) })
    append_wrapped_instruction(lines, "  ", item.review_note)
  end
  vim.list_extend(lines, { instruction(""), instruction("GOAL") })
  local essential_start = #lines
  append_wrapped_instruction(lines, "  ", context.lesson.objective)
  vim.list_extend(lines, { instruction(""), instruction("HOW") })
  for index, step in ipairs(context.lesson.steps or {}) do
    append_wrapped_instruction(lines, ("  %d. "):format(index), step, "     ")
  end
  if context.show_hint and context.lesson.hint then
    vim.list_extend(lines, { instruction(""), instruction("HINT") })
    append_wrapped_instruction(lines, "  ", context.lesson.hint)
  end
  vim.list_extend(lines, { instruction(""), instruction("CONTROLS") })
  local controls =
    "`,h` hint · `,r` reset · `,m` toggle completion · `,s` toggle favourite · `,v` toggle verification · `,i` manage issue · `,c` tasks · `,q` quit"
  if context.lesson.kind == "drill" then
    controls =
      "`<CR>` start/replay · `,h` instructions/hint · `,r` abort/reset · `,m` toggle completion · `,s` toggle favourite · `,v` toggle verification · `,i` manage issue · `,c` tasks · `,q` quit"
    if context.lesson.drill.kind == "scenarios" then
      controls = "`,k` check round · " .. controls
    end
  end
  if context.path then
    controls = controls:gsub(" · `,c`", " · `,n` next path task · `,c`")
  end
  append_wrapped_instruction(lines, "  ", controls)
  vim.list_extend(lines, { instruction(""), instruction("STATUS") })
  local canonical_status = ("Complete: %s · Verified: %s"):format(
    item.completed and "yes" or "no",
    item.review == "verified" and "yes" or "no"
  )
  append_wrapped_instruction(lines, "  ", context.live_drill_status or canonical_status)
  -- A finished drill returns to this panel, so its result must be readable
  -- here. Results of an older task revision are not comparable and stay hidden.
  local record = context.lesson.kind == "drill" and item.drill or nil
  if record and record.last and record.revision == context.lesson.revision then
    local untimed = record.last.details and record.last.details.untimed
    append_wrapped_instruction(
      lines,
      "  ",
      untimed and ("Last: %s · untimed"):format(drills.format_score(record.last))
        or ("Last: %s · Best: %s"):format(drills.format_score(record.last), drills.format_score(record.best))
    )
  end
  vim.list_extend(lines, {
    instruction(""),
    instruction(
      "──────────────────────── EXERCISE ────────────────────────"
    ),
  })
  return lines, essential_start
end

local function contains_identifier(content, identifier)
  local start = 1
  while true do
    local first, last = content:find(identifier, start, true)
    if not first then
      return false
    end
    local before = first > 1 and content:sub(first - 1, first - 1) or ""
    local after = last < #content and content:sub(last + 1, last + 1) or ""
    if not before:match("[%w_]") and not after:match("[%w_]") then
      return true
    end
    start = last + 1
  end
end

local function project_rename_state(context, check)
  local state
  for _, relative in ipairs(check.files) do
    local lines = project_file_lines(context, relative)
    local content = table.concat(lines, "\n")
    local has_old = contains_identifier(content, check.old)
    local has_new = contains_identifier(content, check.new)
    local file_state
    if has_old and not has_new then
      file_state = "original"
    elseif has_new and not has_old then
      file_state = "renamed"
    else
      return "inconsistent"
    end
    if state and state ~= file_state then
      return "inconsistent"
    end
    state = file_state
  end
  return state or "inconsistent"
end

local section_highlights = {
  GOAL = { "DiagnosticWarn", "Bold" },
  HOW = { "DiagnosticWarn", "Bold" },
  HINT = { "DiagnosticWarn", "Bold" },
  CONTROLS = { "DiagnosticWarn", "Bold" },
  STATUS = { "DiagnosticWarn", "Bold" },
  ["REPORTED ISSUE"] = { "DiagnosticError", "Bold" },
  ["PREVIOUS REVIEW NOTE"] = { "DiagnosticWarn", "Bold" },
}

local function append_styled_text(chunks, text, base_highlight)
  local position = 1
  while position <= #text do
    local code_first, code_last = text:find("`[^`]+`", position)
    local separator_first, separator_last = text:find(" · ", position, true)
    local first, last, highlight
    if code_first and (not separator_first or code_first < separator_first) then
      first, last, highlight = code_first, code_last, { "String", "Bold" }
    elseif separator_first then
      first, last, highlight = separator_first, separator_last, "Comment"
    else
      chunks[#chunks + 1] = { text:sub(position), base_highlight }
      return
    end
    if first > position then
      chunks[#chunks + 1] = { text:sub(position, first - 1), base_highlight }
    end
    local content = code_first == first and text:sub(first + 1, last - 1) or text:sub(first, last)
    chunks[#chunks + 1] = { content, highlight }
    position = last + 1
  end
end

local function instruction_chunks(line)
  local rail, body = line:match("^(│ ?)(.*)$")
  if not rail then
    return { { line, "Normal" } }
  end
  local chunks = { { rail, "Comment" } }
  if body == "" then
    return chunks
  end
  if body == "NEOVIM DOJO" then
    chunks[#chunks + 1] = { body, { "Title", "Bold" } }
    return chunks
  end
  if section_highlights[body] then
    chunks[#chunks + 1] = { body, section_highlights[body] }
    return chunks
  end
  if body:find("^─") then
    chunks[#chunks + 1] = { body, "Comment" }
    return chunks
  end
  local label, value = body:match("^([A-Z]+ · )(.*)$")
  if label then
    chunks[#chunks + 1] = { label, { "Special", "Bold" } }
    append_styled_text(chunks, value, "Normal")
    return chunks
  end
  append_styled_text(chunks, body, "Normal")
  return chunks
end

local function reveal_instructions(context, total_count, essential_count)
  local scroll_up = vim.api.nvim_replace_termcodes("<C-y>", true, false, true)
  local function reveal()
    if not vim.api.nvim_tabpage_is_valid(context.tab) or not vim.api.nvim_buf_is_valid(context.buf) then
      return
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(context.tab)) do
      if vim.api.nvim_win_get_buf(win) == context.buf and vim.api.nvim_win_get_config(win).relative == "" then
        vim.api.nvim_win_call(win, function()
          local cursor = vim.api.nvim_win_get_cursor(win)
          local view = vim.fn.winsaveview()
          local available = math.max(vim.api.nvim_win_get_height(win) - cursor[1], 0)
          local desired = available >= total_count and total_count or math.min(essential_count, available)
          local scroll = math.max(view.topline - 1, 0) + desired
          if scroll > 0 then
            vim.cmd.normal({ args = { tostring(scroll) .. scroll_up }, bang = true })
          end
          -- Ctrl-Y may move the cursor when the viewport reaches its limit.
          -- Restore the task position while keeping the revealed virtual
          -- lines. When space is tight, prioritize GOAL through STATUS over
          -- title and metadata.
          vim.api.nvim_win_set_cursor(win, cursor)
        end)
      end
    end
  end

  reveal()
end

-- `status` is shown only while a drill is running; every other panel derives
-- its STATUS section from stored state.
local function render(context, status, reveal)
  if not vim.api.nvim_buf_is_valid(context.buf) then
    return
  end
  local raw_lines, essential_start = instruction_lines(context, status)
  local virtual_lines = vim.tbl_map(function(line)
    return instruction_chunks(line)
  end, raw_lines)
  local options = {
    virt_lines = virtual_lines,
    virt_lines_above = true,
  }
  if context.instruction_mark then
    options.id = context.instruction_mark
  end
  context.instruction_mark = vim.api.nvim_buf_set_extmark(context.buf, instruction_namespace, 0, 0, options)
  if reveal then
    reveal_instructions(context, #virtual_lines, #virtual_lines - essential_start + 1)
  end
end

local function observe_navigation(context)
  if context.lesson.kind == "drill" then
    return
  end
  local check = context.lesson.check
  if context.phase ~= "target" then
    return
  end
  local reached_target = check.kind == "cursor_round_trip" and cursor_on_text(context, check.target)
    or check.kind == "project_round_trip" and project_position(context, check.target)
  if reached_target then
    context.phase = "return"
    render(context)
  end
end

local function lesson_status(context)
  local check = context.lesson.check
  observe_navigation(context)
  local custom = M.options.checkers and M.options.checkers[check.kind]
  if custom then
    return custom(context, check)
  end
  if check.kind == "outcome" then
    return require("neovim_dojo.outcomes").matches(context, check)
  end
  if check.kind == "cursor_on_text" then
    return cursor_on_text(context, check)
  end
  if check.kind == "cursor_round_trip" then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local origin_line = context.exercise_start + check.origin[1] - 1
    -- An optional mark proves the return used a position the learner saved.
    local marked = not check.mark
      or vim.deep_equal(vim.api.nvim_buf_get_mark(context.buf, check.mark.name), check.mark.position)
    return vim.api.nvim_get_current_buf() == context.buf
      and context.phase == "return"
      and cursor[1] == origin_line
      and cursor[2] == check.origin[2]
      and marked
  end
  if check.kind == "project_round_trip" then
    if context.phase ~= "return" then
      return false
    end
    local origin = vim.deepcopy(check.origin)
    if not origin.text and origin.column then
      origin.text = context.lesson.lines[origin.line]:sub(origin.column + 1, origin.column + 1)
    end
    return project_position(context, origin)
  end
  if check.kind == "project_rename" then
    return project_rename_state(context, check) == "renamed"
  end
  if check.kind == "manual" then
    return false
  end
  if check.kind == "buffer_equals" then
    local first = context.exercise_start - 1
    return vim.deep_equal(vim.api.nvim_buf_get_lines(context.buf, first, -1, false), check.lines)
  end
  if check.kind == "undo_branch" then
    local first = context.exercise_start - 1
    local lines_match = vim.deep_equal(vim.api.nvim_buf_get_lines(context.buf, first, -1, false), check.lines)
    return lines_match and undo_branches.has_alternate(vim.fn.undotree().entries)
  end
  if check.kind == "buffer_equals_at_cursor" then
    local first = context.exercise_start - 1
    local lines_match = vim.deep_equal(vim.api.nvim_buf_get_lines(context.buf, first, -1, false), check.lines)
    local cursor = vim.api.nvim_win_get_cursor(0)
    return vim.api.nvim_get_current_buf() == context.buf
      and lines_match
      and cursor[1] == context.exercise_start + check.cursor[1] - 1
      and cursor[2] == check.cursor[2]
  end
  if check.kind == "window_count" then
    local count = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(context.tab)) do
      if vim.api.nvim_win_get_buf(win) == context.buf then
        count = count + 1
      end
    end
    return count >= check.minimum
  end
  if check.kind == "equal_window_widths" then
    local windows = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_buf(win) == context.buf
    end, vim.api.nvim_tabpage_list_wins(context.tab))
    if #windows < check.minimum then
      return false
    end
    local minimum, maximum
    for _, win in ipairs(windows) do
      local width = vim.api.nvim_win_get_width(win)
      minimum = minimum and math.min(minimum, width) or width
      maximum = maximum and math.max(maximum, width) or width
    end
    return maximum - minimum <= 1
  end
  if check.kind == "target_window" then
    return context.target_window
      and vim.api.nvim_win_is_valid(context.target_window)
      and vim.api.nvim_get_current_win() == context.target_window
  end
  if check.kind == "target_buffer" then
    return context.target_buffer
      and vim.api.nvim_buf_is_valid(context.target_buffer)
      and vim.api.nvim_get_current_buf() == context.target_buffer
  end
  if check.kind == "window_narrower" then
    return context.resize_window
      and vim.api.nvim_win_is_valid(context.resize_window)
      and vim.api.nvim_win_get_width(context.resize_window) < context.initial_window_width
  end
  if check.kind == "cmdwin_types" then
    for _, cmdwin_type in ipairs(check.types) do
      if not context.seen_cmdwin_types[cmdwin_type] then
        return false
      end
    end
    return true
  end
  if check.kind == "cmdwin_text" then
    for _, entry in ipairs(context.seen_cmdwin_entries) do
      if entry.type == check.type and entry.text:find(check.text, 1, true) then
        return true
      end
    end
    return false
  end
  return false
end

function M.check()
  local context = current
  if
    not context
    or context.lesson.kind == "drill"
    or context.completed
    or context.completion_suppressed
    or not vim.api.nvim_buf_is_valid(context.buf)
  then
    return false
  end
  if vim.api.nvim_get_current_tabpage() ~= context.tab then
    return false
  end
  if not lesson_status(context) then
    return false
  end

  context.completed = true
  vim.api.nvim_buf_clear_namespace(context.buf, cue_namespace, 0, -1)
  record_pass(context.lesson)
  render(context)
  vim.notify(context.lesson.title .. " completed", vim.log.levels.INFO, { title = "Neovim Dojo" })
  return true
end

function M.toggle_completion(lesson)
  local next_completed = not M.lesson_state(lesson).completed
  if not state.set_completion(lesson, next_completed) then
    return false
  end
  if current and current.lesson.id == lesson.id then
    current.completed = next_completed
    current.completion_suppressed = not next_completed
    if next_completed then
      vim.api.nvim_buf_clear_namespace(current.buf, cue_namespace, 0, -1)
    end
    render(current)
  end
  return true, next_completed
end

function M.set_completions(lessons, completed)
  if not state.set_completions(lessons, completed) then
    return false
  end
  if current then
    for _, lesson in ipairs(lessons) do
      if lesson.id == current.lesson.id then
        current.completed = completed
        current.completion_suppressed = not completed
        render(current)
        break
      end
    end
  end
  return true, #lessons
end

function M.toggle_current_completion()
  local context = current
  if not context or not vim.api.nvim_buf_is_valid(context.buf) then
    return false
  end
  local ok, completed = M.toggle_completion(context.lesson)
  if ok then
    vim.notify(
      context.lesson.title .. (completed and " marked complete" or " marked incomplete"),
      vim.log.levels.INFO,
      { title = "Neovim Dojo" }
    )
  end
  return ok
end

function M.toggle_current_favorite()
  local context = current
  if not context or not vim.api.nvim_buf_is_valid(context.buf) then
    return false
  end
  local ok, favorite = M.toggle_favorite(context.lesson)
  if not ok then
    return false
  end
  local message = favorite and "Lesson starred ★" or "Lesson unstarred"
  render(context)
  vim.notify(message, vim.log.levels.INFO, { title = "Neovim Dojo" })
  return true
end

M.mark_complete = M.toggle_current_completion
M.mark_passed = M.toggle_current_completion

function M.verify_current()
  local context = current
  if not context or not vim.api.nvim_buf_is_valid(context.buf) then
    return false
  end
  local was_verified = M.review_status(context.lesson) == "verified"
  if not M.verify(context.lesson) then
    return false
  end
  local message = was_verified and "Marked unverified" or "Task revision verified ✓"
  render(context)
  vim.notify(message, vim.log.levels.INFO, { title = "Neovim Dojo" })
  return true
end

function M.manage_current_issue()
  local context = current
  if not context or not vim.api.nvim_buf_is_valid(context.buf) then
    return false
  end
  local item = M.lesson_state(context.lesson)
  local existing = item.review == "issue" and item.review_note or nil
  vim.ui.input({
    prompt = existing and "Edit issue (empty removes): " or "Report issue: ",
    default = existing,
  }, function(note)
    if note == nil or current ~= context then
      return
    end
    note = vim.trim(note)
    local ok
    local message
    if note == "" then
      ok = M.clear_review(context.lesson)
      message = "Lesson issue removed"
    else
      ok = M.report_issue(context.lesson, note)
      message = existing and "Lesson issue updated" or "Lesson issue recorded"
    end
    render(context)
    vim.notify(ok and message or "Could not update task issue", ok and vim.log.levels.INFO or vim.log.levels.ERROR, {
      title = "Neovim Dojo",
    })
  end)
  return true
end

-- Most events arrive in the middle of a command, so their check is deferred
-- until the command is done. One deferred check serves a whole burst of events.
local function schedule_check(context)
  context.check_due = true
  if context.check_scheduled then
    return
  end
  context.check_scheduled = true
  vim.schedule(function()
    context.check_scheduled = false
    if current == context and context.check_due then
      context.check_due = false
      M.check()
    end
  end)
end

-- SafeState is the idle boundary itself, so its check runs at once. It must
-- not be deferred: a scheduled callback wakes the editor, the editor raises
-- SafeState again when it has run, and an open task would never be idle.
local function check_when_idle(context)
  context.check_due = false
  if current == context then
    M.check()
  end
end

local function apply_session_mappings(buf)
  if not current or current.mapped_buffers[buf] then
    return
  end
  current.mapped_buffers[buf] = true
  local mappings = {
    [controls.lhs("h")] = { M.hint, "Show hint" },
    [controls.lhs("r")] = { M.reset, "Reset task" },
    [controls.lhs("m")] = { M.toggle_current_completion, "Toggle task completion" },
    [controls.lhs("s")] = { M.toggle_current_favorite, "Toggle task favourite" },
    [controls.lhs("v")] = { M.verify_current, "Toggle task verification" },
    [controls.lhs("i")] = { M.manage_current_issue, "Manage task issue" },
    [controls.lhs("c")] = {
      function()
        M.open()
      end,
      "Choose Neovim Dojo task",
    },
    [controls.lhs("q")] = { M.quit, "Quit Neovim Dojo" },
  }
  if current and current.path then
    mappings[controls.lhs("n")] = { M.start_next_path_entry, "Start next learning-path task" }
  end
  for key, action in pairs(mappings) do
    vim.keymap.set("n", key, action[1], { buffer = buf, desc = action[2] })
  end
  local owns_auxiliary_buffer = current and vim.tbl_contains(current.auxiliary_buffers or {}, buf)
  local drill_owns_buffer = current
    and current.drill_runtime
    and current.drill_runtime.owns_buffer
    and current.drill_runtime:owns_buffer(buf)
  if
    current
    and current.drill_runtime
    and (current.buf == buf or owns_auxiliary_buffer or project_relative_path(current, buf) or drill_owns_buffer)
  then
    current.drill_runtime:apply_mappings(buf)
  end
  if M.options.on_mappings then
    M.options.on_mappings(buf, current)
  end
end

local function install_session_autocmds(context)
  local group = vim.api.nvim_create_augroup(session_group, { clear = true })
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "CursorMoved",
    "InsertLeave",
    "TextChanged",
    "TextChangedI",
    "TextYankPost",
    "RecordingLeave",
    "SafeState",
    "WinEnter",
    "WinNew",
    "WinResized",
  }, {
    group = group,
    callback = function(event)
      local buf = vim.api.nvim_get_current_buf()
      local drill_owns_buffer = context.drill_runtime
        and context.drill_runtime.owns_buffer
        and context.drill_runtime:owns_buffer(buf)
      local owns_auxiliary_buffer = vim.tbl_contains(context.auxiliary_buffers or {}, buf)
      if buf == context.buf or owns_auxiliary_buffer or project_relative_path(context, buf) or drill_owns_buffer then
        apply_session_mappings(buf)
        if context.drill_runtime then
          context.drill_runtime:on_event(event)
        else
          observe_navigation(context)
        end
      end
      if M.options.on_event then
        M.options.on_event(context, event)
      end
      if event.event == "SafeState" then
        check_when_idle(context)
      else
        schedule_check(context)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = context.buf,
    callback = function()
      -- Retire the owned fixtures after Neovim finishes wiping this buffer.
      -- Keep the replacement buffer/tab chosen by the user intact.
      context.primary_wiped = true
      vim.schedule(function()
        if current == context then
          M.quit()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("CmdwinEnter", {
    group = group,
    callback = function()
      local entry = {
        type = vim.fn.getcmdwintype(),
        text = vim.api.nvim_get_current_line(),
      }
      context.seen_cmdwin_types[entry.type] = true
      context.seen_cmdwin_entries[#context.seen_cmdwin_entries + 1] = entry
      schedule_check(context)
    end,
  })
end

local function write_project_support_files(context)
  for relative, lines in pairs(context.lesson.setup.files or {}) do
    local path = context.project_root .. "/" .. relative
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    assert(vim.fn.writefile(lines, path) == 0, "could not create Neovim Dojo file: " .. relative)
  end
end

local function remove_project_support_buffers(context)
  if not context.project_root then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= context.buf and project_relative_path(context, buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

local function remove_auxiliary_buffers(context)
  for _, buf in ipairs(context.auxiliary_buffers or {}) do
    context.mapped_buffers[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  context.auxiliary_buffers = {}
  context.target_buffer = nil
  if context.auxiliary_root then
    vim.fn.delete(context.auxiliary_root, "rf")
    context.auxiliary_root = nil
  end
end

local function retire_project(context)
  if not context.project_root then
    return
  end
  local project_root = normalized(context.project_root)
  local attempts = 0
  local function client_uses_project(client)
    local root = client.config and client.config.root_dir
    if type(root) == "string" and normalized(root) == project_root then
      return true
    end
    for _, folder in ipairs(client.workspace_folders or {}) do
      local path = folder.uri and vim.uri_to_fname(folder.uri)
      if path and normalized(path) == project_root then
        return true
      end
    end
    return false
  end

  local function stop_clients_then_remove()
    attempts = attempts + 1
    for _, client in ipairs(vim.lsp.get_clients()) do
      if client_uses_project(client) then
        pcall(function()
          client:stop()
        end)
      end
    end

    -- LSP startup is asynchronous. Keep the disposable project around for a
    -- short grace period so a client already being spawned can acquire its
    -- root, then stop only clients rooted in this exact Dojo project. Clients
    -- rooted elsewhere may share the session and must remain untouched.
    if attempts < 60 then
      vim.defer_fn(stop_clients_then_remove, 50)
      return
    end
    vim.fn.delete(project_root, "rf")
  end
  stop_clients_then_remove()
end

local function set_lesson_lines(context)
  context.exercise_start = 1
  local lines = vim.deepcopy(context.lesson.lines)
  vim.bo[context.buf].modifiable = true
  vim.api.nvim_buf_set_lines(context.buf, 0, -1, false, lines)
  if context.project_root then
    -- Keep Neovim's file timestamp in sync. Writing this file with
    -- vim.fn.writefile() makes it look like another process changed the
    -- disposable project and causes W13 on the next buffer write.
    vim.api.nvim_buf_call(context.buf, function()
      vim.cmd("silent noautocmd write")
    end)
  else
    vim.bo[context.buf].modified = false
  end
  vim.api.nvim_buf_clear_namespace(context.buf, cue_namespace, 0, -1)
  for _, cue in ipairs(context.lesson.cues or {}) do
    local line = assert(context.lesson.lines[cue.line], "Dojo cue line is outside the task")
    local first = assert(line:find(cue.text, 1, true), "Dojo cue text is missing from the task") - 1
    vim.api.nvim_buf_set_extmark(context.buf, cue_namespace, cue.line - 1, first, {
      end_col = first + #cue.text,
      hl_group = cue.highlight or highlights.target,
      priority = highlights.persistent_priority,
    })
  end
  local cursor = context.lesson.cursor or { 1, 0 }
  vim.api.nvim_win_set_cursor(0, { context.exercise_start + cursor[1] - 1, cursor[2] })
end

local function apply_lesson_setup(context)
  local setup = context.lesson.setup
  local custom = setup and M.options.setups and M.options.setups[setup.kind]
  if custom then
    custom(context, setup)
    return
  end
  if setup and setup.kind == "clear_undo_history" then
    if setup.allow_undotree then
      -- Undotree deliberately ignores `nofile` buffers. `acwrite` keeps this
      -- URI-backed task disposable while exposing its native undo graph.
      vim.bo[context.buf].buftype = "acwrite"
    end
    undo_branches.clear_history(context.buf)
  elseif setup and setup.kind == "buffer_navigation" then
    -- These tasks intentionally replace the buffer displayed in the current
    -- window. Keep the primary task alive while hidden; quit still force-wipes it.
    vim.bo[context.buf].bufhidden = "hide"
    context.auxiliary_root = vim.fn.tempname() .. "-neovim-dojo-buffers"
    vim.fn.mkdir(context.auxiliary_root, "p")
    for _, specification in ipairs(setup.buffers or {}) do
      local buf = vim.api.nvim_create_buf(true, false)
      vim.bo[buf].swapfile = false
      vim.bo[buf].undofile = false
      vim.bo[buf].bufhidden = "hide"
      local path = context.auxiliary_root .. "/" .. specification.name .. ".txt"
      assert(vim.fn.writefile(specification.lines, path) == 0, "could not write Dojo buffer fixture")
      vim.api.nvim_buf_set_name(buf, path)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, specification.lines)
      vim.bo[buf].filetype = "text"
      vim.bo[buf].modified = false
      context.auxiliary_buffers[#context.auxiliary_buffers + 1] = buf
      if specification.target then
        context.target_buffer = buf
      end
    end
    if setup.prime_alternate and context.target_buffer then
      vim.api.nvim_win_set_buf(0, context.target_buffer)
      vim.api.nvim_win_set_buf(0, context.buf)
    end
  elseif setup and setup.kind == "unequal_vertical_splits" then
    vim.cmd.vsplit()
    vim.cmd("vertical resize 15")
  elseif setup and vim.tbl_contains({ "native_window_navigation", "resize_vertical_splits" }, setup.kind) then
    vim.cmd.vsplit()
    vim.cmd("wincmd =")
    local windows = vim.api.nvim_tabpage_list_wins(context.tab)
    table.sort(windows, function(left, right)
      return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
    end)
    vim.api.nvim_set_current_win(windows[1])
    if setup.kind == "native_window_navigation" then
      context.target_window = windows[2]
    else
      context.resize_window = windows[1]
      context.initial_window_width = vim.api.nvim_win_get_width(windows[1])
    end
  end
end

local function stop_owned_recording(context)
  local recording = vim.fn.reg_recording():lower()
  if recording ~= "" and context.saved_registers[recording] then
    vim.cmd.normal({ args = { "q" }, bang = true })
  end
end

function M.reset()
  local context = current
  if not context or not vim.api.nvim_tabpage_is_valid(context.tab) or not vim.api.nvim_buf_is_valid(context.buf) then
    return
  end
  stop_owned_recording(context)
  if M.options.before_reset then
    M.options.before_reset(context)
  end
  vim.api.nvim_set_current_tabpage(context.tab)
  vim.cmd("silent! only!")
  -- Deleting the last displayed auxiliary can close its tab. Put the primary
  -- back in the window first, so reset cannot migrate into the user's tab.
  vim.api.nvim_win_set_buf(0, context.buf)
  remove_auxiliary_buffers(context)
  remove_project_support_buffers(context)
  if context.project_root then
    write_project_support_files(context)
  end
  vim.api.nvim_win_set_buf(0, context.buf)
  context.completed = false
  context.completion_suppressed = false
  context.phase = "target"
  context.target_window = nil
  context.resize_window = nil
  context.initial_window_width = nil
  context.seen_cmdwin_types = {}
  context.seen_cmdwin_entries = {}
  if context.drill_runtime then
    context.drill_active = false
    context.drill_runtime:reset()
  else
    if context.lesson.setup and context.lesson.setup.kind == "project" then
      context.exercise_start = 1
    else
      set_lesson_lines(context)
    end
    -- Again on every reset: a learner may have changed them (`zM` lowers
    -- 'foldlevel'), and new text recomputes what depends on them.
    for name, value in pairs(context.lesson.options or {}) do
      vim.api.nvim_set_option_value(name, value, { scope = "local" })
    end
    -- Folds made by hand outlive the text they were made on.
    if vim.wo.foldmethod == "manual" then
      vim.cmd("silent! normal! zE")
    end
    apply_lesson_setup(context)
  end
  -- Add the virtual instruction panel only after the task cursor and any
  -- task windows are in place. Moving or resizing a window after adding
  -- virtual lines can scroll those lines out of the initial viewport.
  render(context, nil, true)
end

function M.hint()
  if current then
    local drill_active = current.drill_active
    current.show_hint = true
    current.live_drill_status = drill_active and current.drill_runtime and current.drill_runtime:status() or nil
    current.drill_active = false
    render(current, nil, true)
    if vim.api.nvim_get_current_buf() ~= current.buf then
      if current.hint_window and vim.api.nvim_win_is_valid(current.hint_window) then
        vim.api.nvim_set_current_win(current.hint_window)
      else
        local buf = vim.api.nvim_create_buf(false, true)
        current.auxiliary_buffers[#current.auxiliary_buffers + 1] = buf
        local lines = instruction_lines(current, nil)
        lines = vim.tbl_map(without_instruction_markup, lines)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = "wipe"
        local width = math.min(76, vim.o.columns - 4)
        local height = math.min(#lines, vim.o.lines - 6)
        current.hint_window = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          row = 1,
          col = math.max(0, math.floor((vim.o.columns - width) / 2)),
          width = width,
          height = height,
          style = "minimal",
          border = "single",
        })
        vim.wo.wrap = true
        apply_session_mappings(buf)
        vim.keymap.set("n", "q", function()
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end, { buffer = buf, desc = "Close Dojo instructions" })
      end
    end
    current.drill_active = drill_active
    current.show_hint = false
    current.live_drill_status = nil
  end
end

function M.quit()
  local context = current
  if not context then
    return
  end
  current = nil
  pcall(vim.api.nvim_del_augroup_by_name, session_group)
  stop_owned_recording(context)
  if M.options.before_quit then
    M.options.before_quit(context)
  end
  if context.drill_runtime then
    context.drill_runtime:close()
  end
  if not context.primary_wiped and vim.api.nvim_tabpage_is_valid(context.tab) then
    vim.api.nvim_set_current_tabpage(context.tab)
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd("tabclose!")
    else
      vim.cmd.enew()
    end
  end
  if context.project_root then
    remove_project_support_buffers(context)
  end
  remove_auxiliary_buffers(context)
  if vim.api.nvim_buf_is_valid(context.buf) then
    pcall(vim.api.nvim_buf_delete, context.buf, { force = true })
  end
  retire_project(context)
  for name, info in pairs(context.saved_registers) do
    if name ~= '"' then
      vim.fn.setreg(name, info)
    end
  end
  if context.saved_registers['"'] then
    vim.fn.setreg('"', context.saved_registers['"'])
  end
end

function M.start(id, path_id)
  local lesson = registry.get(id)
  if not lesson then
    vim.notify("Unknown Neovim Dojo task: " .. tostring(id), vim.log.levels.ERROR, { title = "Neovim Dojo" })
    return false
  end
  local available, missing = M.availability(lesson)
  if not available then
    vim.notify("Task unavailable: " .. table.concat(missing, ", "), vim.log.levels.WARN, { title = lesson.title })
    return false
  end
  local path = path_id and registry.path(path_id) or nil
  local path_position = path and path_entry_position(path, lesson.id) or nil
  if not path_id then
    path, path_position = filtered_path_for(lesson.id)
  elseif not path_position then
    path = nil
  end
  if current then
    M.quit()
  end
  local saved_registers = {}
  for _, name in ipairs(lesson.preserve_registers or {}) do
    saved_registers[name] = vim.fn.getreginfo(name)
  end
  if next(saved_registers) then
    saved_registers['"'] = vim.fn.getreginfo('"')
  end
  state.record_attempt(lesson)

  vim.cmd.tabnew()
  -- Dojo buffers are disposable. Disable swap before assigning a URI or
  -- opening a temporary project file; setting it afterwards is too late to
  -- prevent E325 when a stale swap file exists for the name.
  vim.bo.swapfile = false
  local project_root
  local entry_relative
  if lesson.setup and (lesson.setup.kind == "python_project" or lesson.setup.kind == "project") then
    project_root = normalized(vim.fn.tempname() .. "-neovim-dojo")
    entry_relative = lesson.setup.entry
    vim.fn.mkdir(project_root, "p")
    -- The directory may be a symlinked alias until it exists.
    project_root = normalized(project_root)
    fixture_roots[project_root] = true
    local temporary_context = { lesson = lesson, project_root = project_root }
    write_project_support_files(temporary_context)
    if lesson.setup.kind == "project" then
      local entry = project_root .. "/" .. entry_relative
      vim.fn.mkdir(vim.fs.dirname(entry), "p")
      assert(vim.fn.writefile(lesson.lines or { "Press Enter to start." }, entry) == 0)
      -- bufadd emits the real named-buffer event used by project consumers.
      -- Defer reading/FileType until the curriculum has finished preparation.
      local empty = vim.api.nvim_get_current_buf()
      local primary = vim.fn.bufadd(entry)
      vim.cmd("silent noautocmd buffer " .. primary)
      if empty ~= primary and vim.api.nvim_buf_is_valid(empty) then
        pcall(vim.api.nvim_buf_delete, empty, { force = true })
      end
    else
      vim.cmd.edit(vim.fn.fnameescape(project_root .. "/" .. entry_relative))
    end
    vim.cmd.tcd(vim.fn.fnameescape(project_root))
  end

  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].swapfile = false
  if not project_root then
    local name = "neovim-dojo://" .. lesson.id
    local stale = vim.fn.bufnr(name)
    if stale ~= -1 and stale ~= buf and vim.api.nvim_buf_is_valid(stale) then
      pcall(vim.api.nvim_buf_delete, stale, { force = true })
    end
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = lesson.filetype or "text"
  end
  vim.bo[buf].undofile = false
  -- After the filetype, so a task's own options win over its ftplugin.
  for name, value in pairs(lesson.options or {}) do
    vim.api.nvim_set_option_value(name, value, { scope = "local" })
  end

  current = {
    lesson = lesson,
    path = path,
    path_position = path_position,
    buf = buf,
    tab = vim.api.nvim_get_current_tabpage(),
    project_root = project_root,
    entry_relative = entry_relative,
    auxiliary_buffers = {},
    mapped_buffers = {},
    relative_paths = {},
    saved_registers = saved_registers,
    phase = "target",
    completed = false,
    completion_suppressed = false,
    seen_cmdwin_types = {},
    seen_cmdwin_entries = {},
  }

  if lesson.kind == "drill" then
    current.drill_runtime = drills.create(current, {
      random = M.options.drill_random,
      clock = M.options.drill_clock,
      status = function(status, reveal)
        if current and current.lesson.id == lesson.id then
          local first_active_render = not current.drill_active
          current.drill_active = true
          render(current, status, first_active_render or reveal)
        end
      end,
      complete = function(result, set_status)
        if not current or current.lesson.id ~= lesson.id then
          return
        end
        local ok, record = state.record_drill_result(lesson, result)
        if not ok then
          vim.notify("Could not save Neovim Dojo drill result", vim.log.levels.ERROR, { title = "Neovim Dojo" })
          return
        end
        current.completed = true
        current.drill_active = false
        local elapsed = drills.format_score(record.last)
        local untimed = result.details and result.details.untimed
        local summary = untimed and ("Finished · %s · untimed"):format(elapsed)
          or record.personal_best and ("Finished · %s · NEW PERSONAL BEST"):format(elapsed)
          or ("Finished · %s · personal best %s"):format(elapsed, drills.format_score(record.best))
        set_status(summary .. " · press <CR> to replay")
        render(current, nil, true)
        vim.notify(summary, vim.log.levels.INFO, { title = lesson.title })
      end,
    }, M.options.drills)
  end

  apply_session_mappings(buf)

  install_session_autocmds(current)
  M.reset()
  return true
end

function M.open()
  local ui = M.options.ui
  if not ui then
    ui = Snacks and Snacks.picker and require("neovim_dojo.ui.snacks") or require("neovim_dojo.ui.builtin")
  end
  ui.open(M)
end

function M.clear_progress(force)
  if not force and vim.fn.confirm("Clear all Neovim Dojo progress?", "&Clear\n&Keep", 2) ~= 1 then
    return false
  end
  state.clear_progress()
  vim.notify("Neovim Dojo progress cleared", vim.log.levels.INFO, { title = "Neovim Dojo" })
  return true
end

return M
