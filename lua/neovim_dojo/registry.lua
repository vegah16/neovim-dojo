local M = {}

local topics = {}
local lessons = {}
local paths = {}
local lesson_by_id = {}
local topic_by_id = {}
local path_by_id = {}
-- Changes a later curriculum makes to tasks of an earlier one, applied once
-- every curriculum is registered.
local overrides = {}

local function merge_unique(...)
  local result, seen = {}, {}
  for index = 1, select("#", ...) do
    local values = select(index, ...)
    for _, value in ipairs(values or {}) do
      if not seen[value] then
        result[#result + 1] = value
        seen[value] = true
      end
    end
  end
  return result
end

local function normalize_source(source)
  if type(source) == "string" then
    return { kind = source }
  end
  return vim.tbl_deep_extend("force", { kind = "neovim" }, source or {})
end

local function validate_lesson(lesson)
  assert(type(lesson.id) == "string" and lesson.id ~= "", "Neovim Dojo task id is required")
  assert(not lesson_by_id[lesson.id], "duplicate Neovim Dojo task id: " .. lesson.id)
  assert(type(lesson.title) == "string" and lesson.title ~= "", "task title is required: " .. lesson.id)
  assert(lesson.kind == "lesson" or lesson.kind == "drill", "invalid task kind: " .. lesson.id)
  assert(type(lesson.revision) == "number" and lesson.revision >= 1, "task revision must be >= 1: " .. lesson.id)
  assert(#lesson.topics > 0, "at least one topic is required: " .. lesson.id)
  assert(lesson.options == nil or type(lesson.options) == "table", "task options must be a table: " .. lesson.id)
  local saved_registers = {}
  for _, name in ipairs(lesson.preserve_registers or {}) do
    assert(type(name) == "string" and name:match('^[a-z0-9"-]$'), "invalid local register: " .. lesson.id)
    assert(not saved_registers[name], "duplicate preserved register: " .. lesson.id)
    saved_registers[name] = true
  end
  for _, parser in ipairs((lesson.requires or {}).parsers or {}) do
    assert(type(parser) == "string" and parser ~= "", "parser requirement must be named: " .. lesson.id)
  end
  for _, cue in ipairs(lesson.cues or {}) do
    assert(lesson.kind == "lesson", "task cues belong to lessons: " .. lesson.id)
    assert(
      type(cue.line) == "number" and cue.line >= 1 and cue.line % 1 == 0,
      "cue line must be a positive integer: " .. lesson.id
    )
    assert(type(cue.text) == "string" and cue.text ~= "", "cue text is required: " .. lesson.id)
    assert(type(lesson.lines) == "table" and lesson.lines[cue.line], "cue line is outside the task: " .. lesson.id)
    assert(lesson.lines[cue.line]:find(cue.text, 1, true), "cue text is missing from the task: " .. lesson.id)
    assert(cue.highlight == nil or type(cue.highlight) == "string", "cue highlight must be a group name: " .. lesson.id)
  end
  if lesson.kind == "drill" then
    assert(type(lesson.drill) == "table", "drill specification is required: " .. lesson.id)
    assert(type(lesson.drill.kind) == "string" and lesson.drill.kind ~= "", "drill kind is required: " .. lesson.id)
    if lesson.drill.kind == "scenarios" then
      assert(
        type(lesson.drill.rounds) == "number" and lesson.drill.rounds >= 2 and lesson.drill.rounds % 1 == 0,
        "scenario drills need at least two rounds: " .. lesson.id
      )
      assert(
        type(lesson.drill.scenes) == "table" and #lesson.drill.scenes >= lesson.drill.rounds,
        "scenario drills need distinct scenes for their rounds: " .. lesson.id
      )
      for _, scene in ipairs(lesson.drill.scenes) do
        assert(type(scene.goal) == "string" and scene.goal ~= "", "scenario goal required: " .. lesson.id)
        assert(type(scene.lines) == "table" and #scene.lines > 0, "scenario lines required: " .. lesson.id)
        assert(type(scene.check) == "table", "scenario outcome required: " .. lesson.id)
      end
    elseif lesson.drill.kind == "cursor_targets" then
      for _, field in ipairs({ "rounds", "rows", "columns", "distance" }) do
        assert(
          type(lesson.drill[field]) == "number" and lesson.drill[field] > 0 and lesson.drill[field] % 1 == 0,
          ("drill %s must be a positive integer: %s"):format(field, lesson.id)
        )
      end
      assert(
        lesson.drill.distance < lesson.drill.rows + lesson.drill.columns - 1,
        "drill distance must fit within its grid: " .. lesson.id
      )
    elseif lesson.drill.kind == "text_actions" then
      local supported = {
        relative_line = true,
        odd_word = true,
        change_inside = true,
        marked_case = true,
        move_visual_line = true,
        character_motion = true,
        register_recall = true,
        macro_lines = true,
      }
      assert(supported[lesson.drill.variant], "unsupported text-action drill variant: " .. lesson.id)
      assert(
        type(lesson.drill.rounds) == "number" and lesson.drill.rounds > 0 and lesson.drill.rounds % 1 == 0,
        "drill rounds must be a positive integer: " .. lesson.id
      )
      for motion, key in pairs(lesson.drill.repeat_keys or {}) do
        assert(
          lesson.drill.variant == "character_motion"
            and motion:match("^[fFtT]$")
            and type(key) == "string"
            and key ~= "",
          "repeat_keys names the key that repeats f, F, t or T: " .. lesson.id
        )
      end
      if lesson.drill.variant == "register_recall" or lesson.drill.variant == "macro_lines" then
        local needed = lesson.drill.rounds
        if lesson.drill.variant == "register_recall" then
          assert(
            type(lesson.drill.registers) == "table" and #lesson.drill.registers > 0,
            "register drill needs targets"
          )
          local targets = {}
          for _, name in ipairs(lesson.drill.registers) do
            assert(
              type(name) == "string" and name:match("^[a-z]$") and saved_registers[name] and not targets[name],
              "register targets must be unique and preserved"
            )
            targets[name] = true
          end
        else
          local rows, name = lesson.drill.rows, lesson.drill.register
          assert(type(rows) == "number" and rows >= 2 and rows % 1 == 0, "macro drill needs at least two rows")
          assert(
            type(name) == "string" and name:match("^[a-z]$") and saved_registers[name],
            "macro register must be preserved"
          )
          needed = needed * rows
        end
        assert(
          type(lesson.drill.words) == "table" and #lesson.drill.words >= needed,
          "register/macro drill needs tokens"
        )
        local tokens = {}
        for _, word in ipairs(lesson.drill.words) do
          assert(
            type(word) == "string" and word:match("^[a-z]+$") and not tokens[word],
            "register tokens must be distinct words"
          )
          tokens[word] = true
        end
      end
    elseif lesson.drill.kind == "search_targets" then
      for _, field in ipairs({ "rounds", "rows" }) do
        assert(
          type(lesson.drill[field]) == "number" and lesson.drill[field] > 0 and lesson.drill[field] % 1 == 0,
          ("drill %s must be a positive integer: %s"):format(field, lesson.id)
        )
      end
      assert(lesson.drill.rows >= 2, "search-target drills need at least two rows: " .. lesson.id)
      assert(
        type(lesson.drill.templates) == "table" and #lesson.drill.templates > 0,
        "search-target drills need target templates: " .. lesson.id
      )
      assert(type(lesson.drill.prompt) == "string", "search-target drills need a prompt: " .. lesson.id)
      local _, prompt_values = lesson.drill.prompt:gsub("%%s", "")
      for _, template in ipairs(lesson.drill.templates) do
        assert(template:find("%%s"), "search-target templates must contain %s: " .. lesson.id)
      end
      if lesson.drill.choice_sets then
        assert(prompt_values >= 1, "choice-target prompts need a query placeholder: " .. lesson.id)
        assert(
          #lesson.drill.choice_sets >= lesson.drill.rounds,
          "choice-target drills need at least one unique choice set per round: " .. lesson.id
        )
        local match_count
        for _, choice in ipairs(lesson.drill.choice_sets) do
          assert(
            type(choice.query) == "string" and choice.query ~= "" and type(choice.target) == "string",
            "choice-target drills need query and target strings: " .. lesson.id
          )
          assert(type(choice.matches) == "table" and #choice.matches > 1, "choice-target drills need several matches")
          match_count = match_count or #choice.matches
          assert(#choice.matches == match_count, "choice-target rounds must keep a stable match count: " .. lesson.id)
          local target_count = 0
          local seen = {}
          for _, match in ipairs(choice.matches) do
            assert(not seen[match], "choice-target matches must be unique within a round: " .. lesson.id)
            assert(match:find(choice.query, 1, true), "every choice-target match must contain its query: " .. lesson.id)
            seen[match] = true
            target_count = target_count + (match == choice.target and 1 or 0)
          end
          assert(target_count == 1, "choice-target lists must contain their target exactly once: " .. lesson.id)
        end
        assert(match_count < lesson.drill.rows, "choice-target boards need room for distractors: " .. lesson.id)
        assert(
          #lesson.drill.templates >= match_count,
          "choice-target drills need at least one distinct template per match: " .. lesson.id
        )
        assert(
          type(lesson.drill.distractors) == "table"
            and #lesson.drill.distractors >= lesson.drill.rounds * (lesson.drill.rows - match_count),
          "choice-target drills need enough distractors to avoid repeats within a run: " .. lesson.id
        )
        for _, choice in ipairs(lesson.drill.choice_sets) do
          for _, template in ipairs(lesson.drill.templates) do
            assert(
              not template:gsub("%%s", ""):find(choice.query, 1, true),
              "choice-target templates must not add accidental query matches: " .. lesson.id
            )
          end
          for _, distractor in ipairs(lesson.drill.distractors) do
            assert(
              not distractor:find(choice.query, 1, true),
              "choice-target distractors must not contain a drill query: " .. lesson.id
            )
          end
        end
      else
        assert(
          type(lesson.drill.targets) == "table" and #lesson.drill.targets >= lesson.drill.rounds,
          "search-target drills need at least one unique target per round: " .. lesson.id
        )
        assert(
          type(lesson.drill.distractors) == "table" and #lesson.drill.distractors >= lesson.drill.rows - 1,
          "search-target drills need enough distractors for one board: " .. lesson.id
        )
      end
    elseif lesson.drill.kind == "remote_actions" then
      assert(
        lesson.drill.variant == "delete" or lesson.drill.variant == "yank" or lesson.drill.variant == "change",
        "unsupported remote-action drill variant: " .. lesson.id
      )
      for _, field in ipairs({ "rounds", "rows" }) do
        assert(
          type(lesson.drill[field]) == "number" and lesson.drill[field] > 0 and lesson.drill[field] % 1 == 0,
          ("drill %s must be a positive integer: %s"):format(field, lesson.id)
        )
      end
      assert(lesson.drill.rows >= 3, "remote-action drills need an origin, target, and distractor: " .. lesson.id)
      assert(
        type(lesson.drill.origin) == "string" and lesson.drill.origin ~= "",
        "remote-action drills need an origin marker: " .. lesson.id
      )
      assert(
        type(lesson.drill.prompt) == "string" and lesson.drill.prompt ~= "",
        "remote-action drills need a prompt: " .. lesson.id
      )
      assert(
        type(lesson.drill.targets) == "table" and #lesson.drill.targets >= lesson.drill.rounds,
        "remote-action drills need one unique target per round: " .. lesson.id
      )
      assert(
        type(lesson.drill.templates) == "table" and #lesson.drill.templates > 0,
        "remote-action drills need target templates: " .. lesson.id
      )
      for _, template in ipairs(lesson.drill.templates) do
        assert(template:find("%%s"), "remote-action templates must contain %s: " .. lesson.id)
      end
      assert(
        type(lesson.drill.distractors) == "table"
          and #lesson.drill.distractors >= lesson.drill.rounds * (lesson.drill.rows - 2),
        "remote-action drills need enough distractors for stable boards: " .. lesson.id
      )
      if lesson.drill.variant == "change" then
        assert(
          type(lesson.drill.replacement) == "string" and lesson.drill.replacement ~= "",
          "remote change drills need replacement text: " .. lesson.id
        )
      end
    elseif lesson.drill.kind == "syntax_nodes" then
      assert(
        type(lesson.drill.rounds) == "number" and lesson.drill.rounds > 0 and lesson.drill.rounds % 1 == 0,
        "drill rounds must be a positive integer: " .. lesson.id
      )
      assert(
        type(lesson.drill.prompt) == "string" and lesson.drill.prompt ~= "",
        "syntax-node drills need a prompt: " .. lesson.id
      )
      assert(
        type(lesson.drill.fixtures) == "table" and #lesson.drill.fixtures >= lesson.drill.rounds,
        "syntax-node drills need one fixture per round: " .. lesson.id
      )
      for _, fixture in ipairs(lesson.drill.fixtures) do
        local lines = fixture.lines or { fixture.line }
        local target_line = fixture.target_line or 1
        assert(
          type(lines) == "table" and #lines > 0 and type(fixture.target) == "string" and fixture.target ~= "",
          "syntax-node fixtures need lines and target text: " .. lesson.id
        )
        for _, line in ipairs(lines) do
          assert(type(line) == "string", "syntax-node fixture lines must be strings: " .. lesson.id)
        end
        assert(
          type(target_line) == "number" and target_line > 0 and target_line % 1 == 0 and target_line <= #lines,
          "syntax-node target line must exist in its fixture: " .. lesson.id
        )
        assert(
          lines[target_line]:find(fixture.target, 1, true),
          "syntax-node target must occur on its target line: " .. lesson.id
        )
        assert(
          type(fixture.cursor_text or fixture.target) == "string"
            and fixture.target:find(fixture.cursor_text or fixture.target, 1, true),
          "syntax-node cursor text must occur inside its target: " .. lesson.id
        )
      end
    elseif lesson.drill.kind == "window_targets" then
      for _, field in ipairs({ "rounds", "rows" }) do
        assert(
          type(lesson.drill[field]) == "number" and lesson.drill[field] > 0 and lesson.drill[field] % 1 == 0,
          ("drill %s must be a positive integer: %s"):format(field, lesson.id)
        )
      end
      assert(
        type(lesson.drill.prompt) == "string" and lesson.drill.prompt ~= "",
        "window-target drills need a prompt: " .. lesson.id
      )
      assert(
        type(lesson.drill.targets) == "table" and #lesson.drill.targets >= lesson.drill.rounds,
        "window-target drills need one unique target per round: " .. lesson.id
      )
      assert(
        type(lesson.drill.templates) == "table" and #lesson.drill.templates > 0,
        "window-target drills need target templates: " .. lesson.id
      )
      for _, template in ipairs(lesson.drill.templates) do
        assert(template:find("%%s"), "window-target templates must contain %s: " .. lesson.id)
      end
      assert(
        type(lesson.drill.distractors) == "table"
          and #lesson.drill.distractors >= lesson.drill.rounds * (lesson.drill.rows * 2 - 1),
        "window-target drills need enough distractors to avoid repeats within a run: " .. lesson.id
      )
    elseif lesson.drill.kind == "undo_branches" then
      assert(
        type(lesson.drill.rounds) == "number" and lesson.drill.rounds > 0 and lesson.drill.rounds % 1 == 0,
        "undo-branch drill rounds must be a positive integer: " .. lesson.id
      )
      assert(
        type(lesson.drill.scenarios) == "table" and #lesson.drill.scenarios >= lesson.drill.rounds,
        "undo-branch drills need at least one scenario per round: " .. lesson.id
      )
    end
  end
end

local function normalize_lesson(topic, raw)
  local lesson = vim.deepcopy(raw)
  lesson.kind = lesson.kind or "lesson"
  lesson.revision = lesson.revision or 1
  lesson.topics = merge_unique({ topic.id }, topic.topics, lesson.topics)
  local inline = {}
  local teaching = { lesson.objective or "", lesson.hint or "" }
  vim.list_extend(teaching, lesson.steps or {})
  for _, text in ipairs(teaching) do
    for code in text:gmatch("`([^`]+)`") do
      inline[#inline + 1] = code
    end
  end
  lesson.keywords = merge_unique(topic.keywords, lesson.keywords, inline)
  lesson.source = normalize_source(lesson.source or topic.source)
  lesson.requires = vim.tbl_deep_extend("force", vim.deepcopy(topic.requires or {}), lesson.requires or {})
  lesson.bindings = vim.tbl_deep_extend("force", { origin = "native" }, topic.bindings or {}, lesson.bindings or {})
  lesson.curriculum = lesson.curriculum or topic.curriculum
  lesson.topic = topic
  validate_lesson(lesson)
  -- Kept so that an override can rebuild the task from its source.
  lesson.raw = raw
  return lesson
end

local function normalize_path(curriculum, raw)
  local path = vim.deepcopy(raw)
  assert(type(path.id) == "string" and path.id ~= "", "Neovim Dojo path id is required")
  assert(not path_by_id[path.id], "duplicate Neovim Dojo path id: " .. path.id)
  assert(type(path.title) == "string" and path.title ~= "", "path title is required: " .. path.id)
  assert(type(path.description) == "string" and path.description ~= "", "path description is required: " .. path.id)
  assert(type(path.revision) == "number" and path.revision >= 1, "path revision must be >= 1: " .. path.id)
  assert(type(path.entries) == "table" and #path.entries > 0, "path entries are required: " .. path.id)
  local seen = {}
  for _, exercise_id in ipairs(path.entries) do
    assert(type(exercise_id) == "string" and exercise_id ~= "", "path entry id is required: " .. path.id)
    assert(not seen[exercise_id], ("duplicate path entry %s: %s"):format(exercise_id, path.id))
    seen[exercise_id] = true
  end
  path.curriculum = curriculum.id
  return path
end

function M.reset()
  topics, lessons, paths, lesson_by_id, topic_by_id, path_by_id = {}, {}, {}, {}, {}, {}
  overrides = {}
end

function M.register(curriculum)
  assert(type(curriculum) == "table", "Neovim Dojo curriculum must be a table")
  assert(type(curriculum.id) == "string" and curriculum.id ~= "", "curriculum id is required")
  for _, raw_topic in ipairs(curriculum.topics or {}) do
    assert(type(raw_topic.id) == "string" and raw_topic.id ~= "", "topic id is required")
    -- A topic that an earlier curriculum registered is extended: the new
    -- tasks join it, with this curriculum's own defaults for their metadata.
    local topic = topic_by_id[raw_topic.id]
    local defaults = vim.deepcopy(raw_topic)
    defaults.curriculum = curriculum.id
    defaults.lessons = nil
    if not topic then
      topic = defaults
      topic.lessons = {}
      topics[#topics + 1] = topic
      topic_by_id[topic.id] = topic
    end
    for _, raw_lesson in ipairs(raw_topic.lessons or {}) do
      local lesson = normalize_lesson(defaults, raw_lesson)
      lesson.defaults, lesson.topic = defaults, topic
      topic.lessons[#topic.lessons + 1] = lesson
      lessons[#lessons + 1] = lesson
      lesson_by_id[lesson.id] = lesson
    end
  end
  for _, raw_path in ipairs(curriculum.paths or {}) do
    local path = normalize_path(curriculum, raw_path)
    paths[#paths + 1] = path
    path_by_id[path.id] = path
  end
  for id, change in pairs(curriculum.overrides or {}) do
    assert(type(change) == "table", "task override must be a table: " .. tostring(id))
    overrides[#overrides + 1] = { id = id, change = change, curriculum = curriculum.id }
  end
end

local function replace(list, old, new)
  for index, lesson in ipairs(list) do
    if lesson == old then
      list[index] = new
    end
  end
end

-- Rebuild each overridden task from its source plus the given fields. A field
-- replaces the original one whole; the task keeps its ID, topic and position.
local function apply_overrides()
  local pending = overrides
  overrides = {}
  for _, override in ipairs(pending) do
    local old = lesson_by_id[override.id]
    assert(old, ("override for unknown task %s: %s"):format(override.id, override.curriculum))
    assert(override.change.id == nil, "an override cannot rename its task: " .. override.id)
    lesson_by_id[old.id] = nil
    local new = normalize_lesson(old.defaults, vim.tbl_extend("force", old.raw, override.change))
    new.defaults, new.topic = old.defaults, old.topic
    replace(lessons, old, new)
    replace(old.topic.lessons, old, new)
    lesson_by_id[new.id] = new
  end
end

function M.validate_paths()
  apply_overrides()
  for _, path in ipairs(paths) do
    for _, exercise_id in ipairs(path.entries) do
      assert(lesson_by_id[exercise_id], ("unknown path entry %s: %s"):format(exercise_id, path.id))
    end
  end
end

function M.topics()
  return topics
end

function M.lessons()
  return lessons
end

function M.paths()
  return paths
end

function M.get(id)
  return lesson_by_id[id]
end

function M.topic(id)
  return topic_by_id[id]
end

function M.path(id)
  return path_by_id[id]
end

function M.values(facet)
  local values = {}
  for _, lesson in ipairs(lessons) do
    local candidates
    if facet == "topic" then
      candidates = lesson.topics
    elseif facet == "source" then
      candidates = { lesson.source.kind == "plugin" and lesson.source.name or lesson.source.kind }
    elseif facet == "binding" then
      candidates = { lesson.bindings.origin }
    elseif facet == "kind" then
      candidates = { lesson.kind }
    end
    for _, value in ipairs(candidates or {}) do
      values[value] = true
    end
  end
  local result = vim.tbl_keys(values)
  table.sort(result)
  return result
end

return M
