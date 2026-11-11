local registry = require("neovim_dojo.registry")
local drills = require("neovim_dojo.drills")
local state = require("neovim_dojo.state")
local controls = require("neovim_dojo.controls")

local M = {}
local facets = { "path", "topic", "source", "binding", "kind", "review", "completion", "availability" }
local default_filters = { availability = "available" }

local function saved_filters()
  local saved = state.filters()
  if saved == nil then
    return vim.deepcopy(default_filters)
  end
  local result = {}
  for _, facet in ipairs(facets) do
    if type(saved[facet]) == "string" and saved[facet] ~= "all" then
      result[facet] = saved[facet]
    end
  end
  return result
end

local filters = saved_filters()
local back_to_facets = "← Back to facets"

local function reopen(core)
  -- Snacks closes vim.ui.select asynchronously. Opening the next picker in the
  -- same callback can leave a detached input window with no results.
  vim.schedule(function()
    M.open(core)
  end)
end

local function source_name(lesson)
  return lesson.source.kind == "plugin" and lesson.source.name or lesson.source.kind
end

local function contains(values, wanted)
  return vim.tbl_contains(values or {}, wanted)
end

local function matches(core, lesson, path_positions)
  local item = core.lesson_state(lesson)
  if filters.path and not path_positions[lesson.id] then
    return false
  end
  if filters.availability == "available" and not item.available then
    return false
  end
  if filters.availability == "unavailable" and item.available then
    return false
  end
  if filters.topic and not contains(lesson.topics, filters.topic) then
    return false
  end
  if filters.source and source_name(lesson) ~= filters.source then
    return false
  end
  if filters.binding and lesson.bindings.origin ~= filters.binding then
    return false
  end
  if filters.kind and lesson.kind ~= filters.kind then
    return false
  end
  if filters.review and item.review ~= filters.review then
    return false
  end
  if filters.completion == "complete" and not item.completed then
    return false
  end
  if filters.completion == "incomplete" and item.completed then
    return false
  end
  return true
end

local function filter_summary(core)
  local parts = {}
  for _, facet in ipairs(facets) do
    if filters[facet] then
      local value = filters[facet]
      if facet == "path" then
        local path = core.find_path(value)
        value = path and path.title or value
      end
      parts[#parts + 1] = facet .. ":" .. value
    end
  end
  return table.concat(parts, " · ")
end

local function picker_title(core)
  local resume = ""
  if filters.path then
    local progress = core.path_progress(filters.path)
    resume = progress and progress.completed == progress.total and " · path complete · ,M: reset shown"
      or " · ,n: resume path"
  end
  return controls.text("Neovim Dojo · keys: first item · Enter: start · ,f: filter" .. resume)
end

local function list_title(core)
  local summary = filter_summary(core)
  local title = "Tasks · " .. (summary == "" and "all" or summary)
  if filters.path then
    local progress = core.path_progress(filters.path)
    if progress then
      title = title .. (" · %d/%d complete"):format(progress.completed, progress.total)
    end
  end
  return title
end

local function utility_items(core)
  local items = {
    {
      text = "picker key guide bindings controls help",
      guide = true,
    },
  }
  if core.ideas_path and core.ideas_path() then
    items[#items + 1] = {
      text = "task ideas backlog inbox recorded suggestions",
      ideas = true,
    }
  end
  return items
end

local function install_catalogue_totals(picker, total)
  local input = picker.input
  local original_update = input.update
  local namespace = vim.api.nvim_create_namespace("snacks.picker.input")
  input.update = function(self, ...)
    original_update(self, ...)
    if not self.win:valid() then
      return
    end
    local line = {}
    local selected = #picker.list.selected
    if selected > 0 then
      line[#line + 1] = { ("(%d)"):format(selected), "SnacksPickerTotals" }
      line[#line + 1] = { " " }
    end
    line[#line + 1] = { ("%d/%d"):format(picker.list:count(), total), "SnacksPickerTotals" }
    line[#line + 1] = { " " }
    vim.api.nvim_buf_set_extmark(self.win.buf, namespace, 0, 0, {
      id = 999,
      virt_text = line,
      virt_text_pos = "right_align",
    })
  end
  input:update()
end

local function key_guide_lines()
  return vim.tbl_map(controls.text, {
    "# Neovim Dojo picker keys",
    "",
    "This reference is always the first item when the search box is empty.",
    "Type `picker keys` to find it again after searching.",
    "",
    "## Dojo actions",
    "",
    "- `<Enter>`: start the selected task",
    "- `,f`: choose a facet filter",
    "- In a facet's value menu, `<Esc>` or `← Back to facets` returns one level",
    "- `,x`: reset facets to the default `availability:available` filter",
    "- Choose the `path` facet to follow a curated task order",
    "- An active path shows derived `completed/total` progress in the list title",
    "- `,n`: resume the first incomplete Entry in the active path",
    "- `,s`: star or unstar the selected task",
    "- `,v`: toggle verification for the selected task revision",
    "- `,m`: toggle completion for the selected task",
    "- `<Tab>`: select or unselect tasks for a bulk action",
    "- `,M`: set selected tasks, or all shown tasks, complete/incomplete",
    "- `,i`: add, edit, or remove the selected task's issue",
    "- `,a`: record a new task idea",
    "- Select `Task ideas` to browse the recorded idea backlog",
    "- To see reported problems: `,f`, then `review`, then `issue`",
    "- To filter progress: `,f`, then `completion`",
    "",
    "## Task markers",
    "",
    "- `!`: reported issue",
    "- `↻`: task changed since verification",
    "- `○`: verification still needed",
    "- `◇`: verified, but not completed",
    "- `✓`: verified and completed",
    "- `★`: favourite; favourites sort above other tasks outside a path",
    "",
    "## Search and navigation",
    "",
    "- Type in the input box to fuzzy-search task metadata",
    "- `<C-n>` / `<C-p>`: select the next / previous result",
    "- `<C-j>`: confirm the selected result, like `<Enter>`",
    "- `<C-k>`: deliberately disabled; use `<C-p>` to move up",
    "- `j` / `k`: select the next / previous result in normal mode",
    "- `gg` / `G`: select the first / last result",
    "- `/`: focus the search input from the results",
    "- `i` / `a`: resume editing while the input is in normal mode",
    "- `<C-d>` / `<C-u>`: scroll the preview down / up",
    "- `<M-p>`: toggle the preview",
    "- `?`: show Snacks' complete low-level picker mappings",
    "- `q` or `<Esc>`: close the picker",
    "",
    "The comma is the Dojo control prefix (the `prefix` option). Dojo actions work",
    "in normal mode from both the input and result list.",
  })
end

local function markdown_preview(ctx, title, lines)
  ctx.preview:reset()
  ctx.preview:wo({ wrap = true, linebreak = true, breakindent = true })
  ctx.preview:set_title(title)
  ctx.preview:set_lines(lines)
  ctx.preview:highlight({ ft = "markdown" })
end

local function searchable_text(lesson)
  local values = { lesson.title, lesson.objective, lesson.id, lesson.kind, source_name(lesson), lesson.bindings.origin }
  vim.list_extend(values, lesson.topics)
  vim.list_extend(values, lesson.keywords)
  return table.concat(values, " ")
end

local function lesson_marker(item)
  if item.review == "issue" then
    return "!", "DiagnosticError"
  end
  if item.review == "changed" then
    return "↻", "DiagnosticWarn"
  end
  if item.review ~= "verified" then
    return "○", "Special"
  end
  if item.completed then
    return "✓", "DiagnosticOk"
  end
  return "◇", "Comment"
end

local function choose_filter(core)
  vim.ui.select(facets, { prompt = "Filter Neovim Dojo by facet" }, function(facet)
    if not facet then
      reopen(core)
      return
    end
    local values
    if facet == "path" then
      values = vim.tbl_map(function(path)
        return path.id
      end, core.paths())
      table.insert(values, 1, "all")
    elseif facet == "review" then
      values = { "new", "changed", "verified", "issue", "all" }
    elseif facet == "completion" then
      values = { "incomplete", "complete", "all" }
    elseif facet == "availability" then
      values = { "available", "unavailable", "all" }
    else
      values = registry.values(facet)
      table.insert(values, 1, "all")
    end
    table.insert(values, 1, back_to_facets)
    vim.ui.select(values, { prompt = "Filter " .. facet }, function(value)
      if value == nil or value == back_to_facets then
        -- Snacks closes vim.ui.select asynchronously, just like the main
        -- catalogue. Returning on the next tick avoids detached nested menus.
        vim.schedule(function()
          choose_filter(core)
        end)
        return
      end
      M.set_filter(facet, value)
      reopen(core)
    end)
  end)
end

local function capture_idea(core, context)
  vim.ui.input({ prompt = "Dojo idea: " }, function(title)
    if not title or vim.trim(title) == "" then
      M.open(core)
      return
    end
    vim.ui.input({ prompt = "Notes (optional): " }, function(note)
      local ok = core.add_idea({
        title = vim.trim(title),
        note = note and vim.trim(note) or "",
        task = context.lesson,
        query = context.query,
        facets = vim.deepcopy(filters),
      })
      vim.notify(
        ok and "Dojo idea recorded" or "Could not record Dojo idea",
        ok and vim.log.levels.INFO or vim.log.levels.ERROR,
        {
          title = "Neovim Dojo",
        }
      )
      M.open(core)
    end)
  end)
end

local function set_bulk_completion(core, picker)
  local selected = picker:selected()
  local candidates = #selected > 0 and selected or picker:items()
  local tasks = {}
  local seen = {}
  for _, item in ipairs(candidates) do
    if item.lesson and not seen[item.lesson.id] then
      tasks[#tasks + 1] = item.lesson
      seen[item.lesson.id] = true
    end
  end
  if #tasks == 0 then
    vim.notify("No tasks selected or shown", vim.log.levels.WARN, { title = "Neovim Dojo" })
    return
  end
  local scope = #selected > 0 and "selected" or "shown"
  picker:close()
  vim.schedule(function()
    vim.ui.select({ "incomplete", "complete" }, {
      prompt = ("Set %d %s tasks"):format(#tasks, scope),
    }, function(choice)
      if not choice then
        reopen(core)
        return
      end
      local completed = choice == "complete"
      local ok, count = core.set_completions(tasks, completed)
      vim.notify(
        ok and ("Set %d tasks %s"):format(count, choice) or "Could not update task completion",
        ok and vim.log.levels.INFO or vim.log.levels.ERROR,
        { title = "Neovim Dojo" }
      )
      reopen(core)
    end)
  end)
end

function M.active_filters()
  return vim.deepcopy(filters)
end

function M.set_filter(facet, value)
  assert(vim.tbl_contains(facets, facet), "unknown Neovim Dojo facet: " .. tostring(facet))
  if value == nil or value == "all" then
    filters[facet] = nil
  else
    filters[facet] = value
  end
  state.set_filters(filters)
end

function M.reset_filters()
  filters = vim.deepcopy(default_filters)
  state.set_filters(filters)
end

function M.open(core)
  local function finder()
    local items = utility_items(core)
    local lesson_items = {}
    local active_path = filters.path and core.find_path(filters.path) or nil
    local path_positions = {}
    if active_path then
      for position, exercise_id in ipairs(active_path.entries) do
        path_positions[exercise_id] = position
      end
    end
    for order, lesson in ipairs(core.lessons()) do
      if matches(core, lesson, path_positions) then
        local item_state = core.lesson_state(lesson)
        lesson_items[#lesson_items + 1] = {
          text = searchable_text(lesson) .. (item_state.favorite and " favorite favourite starred" or ""),
          lesson = lesson,
          state = item_state,
          order = path_positions[lesson.id] or order,
          path = active_path,
          path_position = path_positions[lesson.id],
        }
      end
    end
    table.sort(lesson_items, function(left, right)
      if not active_path and left.state.favorite ~= right.state.favorite then
        return left.state.favorite
      end
      return left.order < right.order
    end)
    vim.list_extend(items, lesson_items)
    return items
  end

  Snacks.picker.pick({
    source = "neovim_dojo",
    title = picker_title(core),
    pattern = "",
    on_show = function(picker)
      install_catalogue_totals(picker, #core.lessons() + #utility_items(core))
    end,
    finder = finder,
    format = function(item)
      if item.guide then
        return {
          { "ⓘ ", "Special" },
          { "Picker key guide", "SnacksPickerLabel" },
          { "  all Dojo picker controls and descriptions", "SnacksPickerComment" },
        }
      end
      if item.ideas then
        return {
          { "✎ ", "Special" },
          { "Task ideas", "SnacksPickerLabel" },
          { "  browse the recorded idea backlog", "SnacksPickerComment" },
        }
      end
      local lesson = item.lesson
      local unavailable = item.state.available and "" or "  unavailable"
      local path_position = item.path and (" · path %d/%d"):format(item.path_position, #item.path.entries) or ""
      local marker, marker_highlight = lesson_marker(item.state)
      return {
        { item.state.favorite and "★ " or "  ", item.state.favorite and "DiagnosticWarn" or "Comment" },
        { marker .. " ", marker_highlight },
        { lesson.title, "SnacksPickerLabel" },
        {
          ("  %s · %s · %s%s%s"):format(
            lesson.kind,
            table.concat(lesson.topics, ","),
            source_name(lesson),
            path_position,
            unavailable
          ),
          "SnacksPickerComment",
        },
      }
    end,
    preview = function(ctx)
      if ctx.item.guide then
        markdown_preview(ctx, "Picker key guide", key_guide_lines())
        return
      end
      if ctx.item.ideas then
        markdown_preview(ctx, "Task ideas", core.idea_lines())
        return
      end
      local lesson, item = ctx.item.lesson, ctx.item.state
      local missing = #item.missing > 0 and table.concat(item.missing, ", ") or "none"
      local lines = {
        "# " .. lesson.title,
        "",
        lesson.objective,
        "",
        "- Kind: `" .. lesson.kind .. "`",
        "- Topics: `" .. table.concat(lesson.topics, "`, `") .. "`",
        "- Source: `" .. source_name(lesson) .. "`",
        "- Binding: `" .. lesson.bindings.origin .. "`",
        "- Review: `" .. item.review .. "` at task revision " .. lesson.revision,
        "- Completion: `" .. (item.completed and "complete" or "incomplete") .. "`",
        "- Favourite: `" .. (item.favorite and "yes" or "no") .. "`",
        "- Practice: " .. item.passes .. " passes from " .. item.attempts .. " attempts",
        "- Available: " .. tostring(item.available) .. " (missing: " .. missing .. ")",
      }
      if ctx.item.path then
        table.insert(
          lines,
          5,
          ("- Path: `%s` (%d/%d)"):format(ctx.item.path.title, ctx.item.path_position, #ctx.item.path.entries)
        )
      end
      if lesson.kind == "drill" then
        local record = item.drill
        vim.list_extend(lines, {
          "- Completed runs: " .. (record and record.runs or 0),
          "- Personal best: `" .. drills.format_score(record and record.best) .. "`",
          "- Last result: `" .. drills.format_score(record and record.last) .. "`",
        })
      end
      vim.list_extend(lines, { "", "## How", "" })
      for index, step in ipairs(lesson.steps or {}) do
        lines[#lines + 1] = index .. ". " .. step
      end
      if lesson.hint then
        vim.list_extend(lines, { "", "## Hint", "", lesson.hint })
      end
      if item.review_note then
        local heading = item.review == "issue" and "## Reported issue" or "## Previous review note"
        vim.list_extend(lines, {
          "",
          heading,
          "",
          item.review_note,
          "",
          "Recorded: " .. (item.reviewed_at or "unknown") .. " at revision " .. (item.reviewed_revision or "unknown"),
        })
      end
      markdown_preview(ctx, lesson.title, lines)
    end,
    confirm = function(picker, item)
      if not item or item.guide then
        return
      end
      if item.ideas then
        picker:close()
        vim.schedule(function()
          vim.cmd.edit(vim.fn.fnameescape(core.ideas_path()))
        end)
        return
      end
      if not item.state.available then
        vim.notify(
          "Lesson unavailable: " .. table.concat(item.state.missing, ", "),
          vim.log.levels.WARN,
          { title = "Neovim Dojo" }
        )
        return
      end
      picker:close()
      vim.schedule(function()
        core.start(item.lesson.id, item.path and item.path.id or nil)
      end)
    end,
    actions = {
      dojo_select = function(picker)
        picker.list:select()
      end,
      dojo_filter = function(picker)
        picker:close()
        vim.schedule(function()
          choose_filter(core)
        end)
      end,
      dojo_clear_filters = function(picker)
        M.reset_filters()
        if picker.list and picker.list.win then
          picker.list.win:set_title(list_title(core))
        end
        picker:refresh()
      end,
      dojo_next_path_entry = function(picker)
        local entry = filters.path and core.next_path_entry(filters.path) or nil
        if not entry or not entry.available then
          core.start_next_path_entry(filters.path, { from_start = true })
          return
        end
        picker:close()
        vim.schedule(function()
          core.start_next_path_entry(filters.path, { from_start = true })
        end)
      end,
      dojo_verify = function(picker, item)
        if item and item.lesson then
          local was_verified = item.state.review == "verified"
          if not core.verify(item.lesson) then
            return
          end
          vim.notify(was_verified and "Task marked unverified" or "Task revision verified", vim.log.levels.INFO, {
            title = "Neovim Dojo",
          })
          picker:refresh()
        end
      end,
      dojo_completion = function(picker, item)
        if not item or not item.lesson then
          return
        end
        local ok, completed = core.toggle_completion(item.lesson)
        if not ok then
          return
        end
        vim.notify(completed and "Task marked complete" or "Task marked incomplete", vim.log.levels.INFO, {
          title = "Neovim Dojo",
        })
        if picker.list and picker.list.win then
          picker.list.win:set_title(list_title(core))
        end
        picker:refresh()
      end,
      dojo_bulk_completion = function(picker)
        set_bulk_completion(core, picker)
      end,
      dojo_favorite = function(picker, item)
        if not item or not item.lesson then
          return
        end
        local ok, favorite = core.toggle_favorite(item.lesson)
        if not ok then
          return
        end
        vim.notify(favorite and "Lesson starred" or "Lesson unstarred", vim.log.levels.INFO, {
          title = "Neovim Dojo",
        })
        picker:refresh()
      end,
      dojo_issue = function(picker, item)
        if not item or not item.lesson then
          return
        end
        local existing = item.state.review == "issue" and item.state.review_note or nil
        picker:close()
        vim.schedule(function()
          vim.ui.input({
            prompt = existing and "Edit issue (empty removes): " or "Report issue: ",
            default = existing,
          }, function(note)
            if note == nil then
              reopen(core)
              return
            end
            note = vim.trim(note)
            local ok
            local message
            if note == "" then
              ok = core.clear_review(item.lesson)
              message = "Lesson issue removed"
            else
              ok = core.report_issue(item.lesson, note)
              message = existing and "Lesson issue updated" or "Lesson issue recorded"
            end
            vim.notify(
              ok and message or "Could not update task issue",
              ok and vim.log.levels.INFO or vim.log.levels.ERROR,
              {
                title = "Neovim Dojo",
              }
            )
            reopen(core)
          end)
        end)
      end,
      dojo_idea = function(picker, item)
        local context = {
          lesson = item and item.lesson and item.lesson.id or nil,
          query = picker:filter().pattern,
        }
        picker:close()
        vim.schedule(function()
          capture_idea(core, context)
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<Tab>"] = { "dojo_select", mode = { "n", "i" }, desc = "Toggle selection without moving" },
          ["j"] = { "list_down", mode = "n", desc = "Next task" },
          ["k"] = { "list_up", mode = "n", desc = "Previous task" },
          [controls.lhs("m")] = { "dojo_completion", mode = "n", desc = "Toggle task completion" },
          [controls.lhs("M")] = { "dojo_bulk_completion", mode = "n", desc = "Set completion in bulk" },
          [controls.lhs("s")] = { "dojo_favorite", mode = "n", desc = "Toggle task favourite" },
          [controls.lhs("f")] = { "dojo_filter", mode = "n", desc = "Choose facet filter" },
          [controls.lhs("x")] = { "dojo_clear_filters", mode = "n", desc = "Clear facet filters" },
          [controls.lhs("n")] = filters.path and { "dojo_next_path_entry", mode = "n", desc = "Resume learning path" }
            or nil,
          [controls.lhs("v")] = { "dojo_verify", mode = "n", desc = "Toggle task verification" },
          [controls.lhs("i")] = { "dojo_issue", mode = "n", desc = "Manage task issue" },
          [controls.lhs("a")] = { "dojo_idea", mode = "n", desc = "Record task idea" },
        },
      },
      list = {
        title = list_title(core),
        keys = {
          ["<Tab>"] = { "dojo_select", mode = { "n", "x" }, desc = "Toggle selection without moving" },
          ["j"] = { "list_down", desc = "Next task" },
          ["k"] = { "list_up", desc = "Previous task" },
          [controls.lhs("m")] = { "dojo_completion", desc = "Toggle task completion" },
          [controls.lhs("M")] = { "dojo_bulk_completion", desc = "Set completion in bulk" },
          [controls.lhs("s")] = { "dojo_favorite", desc = "Toggle task favourite" },
          [controls.lhs("f")] = { "dojo_filter", desc = "Choose facet filter" },
          [controls.lhs("x")] = { "dojo_clear_filters", desc = "Clear facet filters" },
          [controls.lhs("n")] = filters.path and { "dojo_next_path_entry", desc = "Resume learning path" } or nil,
          [controls.lhs("v")] = { "dojo_verify", desc = "Toggle task verification" },
          [controls.lhs("i")] = { "dojo_issue", desc = "Manage task issue" },
          [controls.lhs("a")] = { "dojo_idea", desc = "Record task idea" },
        },
      },
    },
  })
end

return M
