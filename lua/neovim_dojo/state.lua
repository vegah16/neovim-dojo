local M = {}

local state_filename = "neovim-dojo.json"
local legacy_filename = "practice.json"
local state_version = 4

local function empty()
  return { version = state_version, lessons = {}, ideas = {}, favorites = {}, ui = {} }
end

local function normalize_string_list(value)
  local result = {}
  local seen = {}
  for _, item in ipairs(type(value) == "table" and value or {}) do
    if type(item) == "string" and item ~= "" and not seen[item] then
      result[#result + 1] = item
      seen[item] = true
    end
  end
  return result
end

local function migrate_legacy(decoded)
  local state = empty()
  for id, progress in pairs(decoded.completed or {}) do
    state.lessons[id] = {
      attempts = progress.count or 1,
      passes = progress.count or 1,
      completed = true,
      last_practised = progress.last_completed,
    }
  end
  return state
end

function M.path()
  return vim.fn.stdpath("state") .. "/" .. state_filename
end

function M.legacy_path()
  return vim.fn.stdpath("state") .. "/" .. legacy_filename
end

function M.load()
  local path = M.path()
  local legacy = false
  if vim.fn.filereadable(path) ~= 1 and vim.fn.filereadable(M.legacy_path()) == 1 then
    path, legacy = M.legacy_path(), true
  end
  if vim.fn.filereadable(path) ~= 1 then
    return empty()
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return empty()
  end
  if legacy or decoded.completed then
    return migrate_legacy(decoded)
  end
  decoded.version = state_version
  decoded.lessons = decoded.lessons or {}
  decoded.ideas = decoded.ideas or {}
  decoded.favorites = normalize_string_list(decoded.favorites)
  decoded.ui = type(decoded.ui) == "table" and decoded.ui or {}
  decoded.ui.filters = type(decoded.ui.filters) == "table" and decoded.ui.filters or nil
  return decoded
end

function M.save(state)
  local path = M.path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temporary = path .. ".tmp"
  local ok, encoded = pcall(vim.json.encode, state)
  local uv = vim.uv or vim.loop
  if not ok or vim.fn.writefile({ encoded }, temporary) ~= 0 or uv.fs_rename(temporary, path) == nil then
    vim.fn.delete(temporary)
    return false
  end
  return true
end

function M.record_pass(lesson)
  local state = M.load()
  local item = state.lessons[lesson.id] or {}
  item.passes = (item.passes or 0) + 1
  item.completed = true
  item.last_practised = os.date("!%Y-%m-%dT%H:%M:%SZ")
  state.lessons[lesson.id] = item
  return M.save(state)
end

function M.record_drill_result(lesson, result)
  assert(type(result.value) == "number" and result.value >= 0, "drill result value must be non-negative")
  assert(type(result.metric) == "string" and result.metric ~= "", "drill result metric is required")
  local dojo_state = M.load()
  local item = dojo_state.lessons[lesson.id] or {}
  local completed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local record = item.drill
  if not record or record.revision ~= lesson.revision or record.metric ~= result.metric then
    record = {
      revision = lesson.revision,
      metric = result.metric,
      unit = result.unit,
      lower_is_better = result.lower_is_better ~= false,
      runs = 0,
    }
  end

  local previous_best = record.best and record.best.value or nil
  local personal_best = previous_best == nil
    or (record.lower_is_better and result.value < previous_best)
    or (not record.lower_is_better and result.value > previous_best)
  local score = {
    value = result.value,
    unit = result.unit,
    at = completed_at,
    details = result.details,
  }
  record.runs = record.runs + 1
  record.last = score
  if personal_best then
    record.best = vim.deepcopy(score)
  end

  item.drill = record
  item.passes = (item.passes or 0) + 1
  item.completed = true
  item.last_practised = completed_at
  dojo_state.lessons[lesson.id] = item
  return M.save(dojo_state),
    {
      personal_best = personal_best,
      previous_best = previous_best,
      best = record.best,
      last = record.last,
      runs = record.runs,
    }
end

function M.is_completed(item)
  if not item then
    return false
  end
  if item.completed ~= nil then
    return item.completed
  end
  return (item.passes or 0) > 0
end

function M.set_completion(lesson, completed)
  local dojo_state = M.load()
  local item = dojo_state.lessons[lesson.id] or {}
  item.completed = completed
  item.completion_changed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  dojo_state.lessons[lesson.id] = item
  return M.save(dojo_state)
end

function M.set_completions(lessons, completed)
  local dojo_state = M.load()
  local changed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  for _, lesson in ipairs(lessons) do
    local item = dojo_state.lessons[lesson.id] or {}
    item.completed = completed
    item.completion_changed_at = changed_at
    dojo_state.lessons[lesson.id] = item
  end
  return M.save(dojo_state)
end

function M.is_favorite(lesson, dojo_state)
  dojo_state = dojo_state or M.load()
  return vim.tbl_contains(dojo_state.favorites or {}, lesson.id)
end

function M.toggle_favorite(lesson)
  local dojo_state = M.load()
  local favorites = {}
  local was_favorite = false
  for _, id in ipairs(dojo_state.favorites or {}) do
    if id == lesson.id then
      was_favorite = true
    else
      favorites[#favorites + 1] = id
    end
  end
  if not was_favorite then
    favorites[#favorites + 1] = lesson.id
  end
  dojo_state.favorites = favorites
  return M.save(dojo_state), not was_favorite
end

function M.filters()
  local filters = (M.load().ui or {}).filters
  return filters and vim.deepcopy(filters) or nil
end

function M.set_filters(filters)
  local dojo_state = M.load()
  dojo_state.ui = dojo_state.ui or {}
  dojo_state.ui.filters = vim.deepcopy(filters)
  return M.save(dojo_state)
end

function M.record_attempt(lesson)
  local state = M.load()
  local item = state.lessons[lesson.id] or {}
  item.attempts = (item.attempts or 0) + 1
  item.last_started = os.date("!%Y-%m-%dT%H:%M:%SZ")
  state.lessons[lesson.id] = item
  return M.save(state)
end

function M.review_status(lesson, state)
  state = state or M.load()
  local review = (state.lessons[lesson.id] or {}).review
  if not review then
    return "new"
  end
  if review.status == "issue" and review.revision == lesson.revision then
    return "issue"
  end
  if review.revision ~= lesson.revision then
    return "changed"
  end
  return "verified"
end

function M.set_review(lesson, status, note)
  local state = M.load()
  local item = state.lessons[lesson.id] or {}
  item.review = {
    status = status,
    revision = lesson.revision,
    at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    note = note,
  }
  state.lessons[lesson.id] = item
  return M.save(state)
end

function M.clear_review(lesson)
  local dojo_state = M.load()
  local item = dojo_state.lessons[lesson.id]
  if not item then
    return true
  end
  item.review = nil
  if not item.attempts and not item.passes and not M.is_completed(item) then
    dojo_state.lessons[lesson.id] = nil
  end
  return M.save(dojo_state)
end

function M.add_idea(idea)
  local state = M.load()
  idea.id = idea.id or ("idea-" .. os.date("!%Y%m%dT%H%M%SZ"))
  idea.created_at = idea.created_at or os.date("!%Y-%m-%dT%H:%M:%SZ")
  state.ideas[#state.ideas + 1] = idea
  return M.save(state), idea
end

function M.clear_progress()
  local state = M.load()
  for id, item in pairs(state.lessons) do
    item.attempts = nil
    item.passes = nil
    item.completed = nil
    item.completion_changed_at = nil
    item.last_practised = nil
    item.last_started = nil
    item.drill = nil
    if not item.review then
      state.lessons[id] = nil
    end
  end
  vim.fn.delete(M.legacy_path())
  return M.save(state)
end

return M
