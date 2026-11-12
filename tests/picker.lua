-- The Snacks picker: its options, rows, facets, previews and actions.
-- Snacks is replaced by a recorder here, so this needs no other plugin.
-- tests/picker_snacks.lua opens the real picker when snacks.nvim is available.
local ideas_path = vim.fn.tempname() .. "-ideas/IDEAS.md"
local function task(id, extra)
  return vim.tbl_extend("force", {
    id = id,
    revision = 1,
    title = "Probe " .. id,
    objective = "Read `" .. id .. "`.",
    steps = { "Press `gx`.", "Then look." },
    hint = "A probe hint.",
    lines = { "fixture" },
    check = { kind = "manual" },
  }, extra or {})
end
local pack = {
  id = "probe-pack",
  topics = {
    {
      id = "probe-topic",
      title = "Probe",
      description = "Picker fixtures.",
      source = { kind = "plugin", name = "probe.nvim" },
      bindings = { origin = "custom" },
      lessons = {
        task("probe-available"),
        task("probe-unavailable", { requires = { capabilities = { "never" } } }),
      },
    },
  },
  paths = {
    {
      id = "probe-path",
      revision = 1,
      title = "Probe path",
      description = "Two tasks.",
      entries = { "balance-splits", "probe-available" },
    },
  },
}
local dojo = require("neovim_dojo")
dojo.setup({
  curricula = { "native", pack },
  ideas_path = ideas_path,
  capabilities = {
    never = function()
      return false
    end,
  },
})
local session = dojo.session
local state = require("neovim_dojo.state")
-- The built-in pack grows, so what the picker should show is counted here.
local native = { tasks = 0, drills = 0, vim = 0 }
for _, lesson in ipairs(session.lessons()) do
  if lesson.curriculum == "native" then
    native.tasks = native.tasks + 1
    native.drills = native.drills + (lesson.kind == "drill" and 1 or 0)
    native.vim = native.vim + (lesson.source.kind == "vim" and 1 or 0)
  end
end
session.clear_progress(true)

local original_snacks, original_select, original_input, original_notify =
  _G.Snacks, vim.ui.select, vim.ui.input, vim.notify
local opened = {}
_G.Snacks = {
  picker = {
    pick = function(options)
      opened[#opened + 1] = options
    end,
  },
}
local notices = {}
vim.notify = function(message, level)
  notices[#notices + 1] = { message = message, level = level }
end
local function last_notice()
  return notices[#notices] or {}
end
-- The picker that `open` hands to Snacks.
local function open()
  local count = #opened
  session.open()
  assert(#opened == count + 1, "opening the Dojo should open exactly one picker")
  return opened[#opened]
end
-- Wait for the scheduled reopen that follows a closed menu or prompt.
local function reopened(count, message)
  assert(
    vim.wait(1000, function()
      return #opened == count
    end),
    message
  )
end
local function tasks(picker)
  return vim.tbl_filter(function(item)
    return item.lesson ~= nil
  end, picker.finder())
end
local function ids(picker)
  return vim.tbl_map(function(item)
    return item.lesson.id
  end, tasks(picker))
end
local function row(picker, id)
  for _, item in ipairs(picker.finder()) do
    if item.lesson and item.lesson.id == id then
      return item
    end
  end
end
local function preview(picker, item)
  local shown = {}
  picker.preview({
    item = item,
    preview = {
      reset = function() end,
      wo = function(_, options)
        shown.wo = options
      end,
      set_title = function(_, title)
        shown.title = title
      end,
      set_lines = function(_, lines)
        shown.text = table.concat(lines, "\n")
      end,
      highlight = function(_, options)
        shown.ft = options.ft
      end,
    },
  })
  return shown
end
-- A stand-in for the Snacks picker object that an action receives.
local function handle(fields)
  local picker = { refreshes = 0, closes = 0, titles = {} }
  picker.refresh = function()
    picker.refreshes = picker.refreshes + 1
  end
  picker.close = function()
    picker.closes = picker.closes + 1
  end
  picker.list = {
    win = {
      set_title = function(_, title)
        picker.titles[#picker.titles + 1] = title
      end,
    },
  }
  for key, value in pairs(fields or {}) do
    picker[key] = value
  end
  return picker
end

-- Options and keys.
local picker = open()
local ui = require("neovim_dojo.ui.snacks")
assert(picker.source == "neovim_dojo", "the picker has its own Snacks source")
assert(picker.pattern == "", "the picker opens with an empty search")
assert(picker.title:find("keys: first item", 1, true), "the title says where the key guide is")
assert(picker.win.list.title == "Tasks · availability:available", "the list title names the active facets")
local input_keys, list_keys = picker.win.input.keys, picker.win.list.keys
for key, action in pairs({
  [",f"] = "dojo_filter",
  [",x"] = "dojo_clear_filters",
  [",s"] = "dojo_favorite",
  [",v"] = "dojo_verify",
  [",i"] = "dojo_issue",
  [",a"] = "dojo_idea",
  [",m"] = "dojo_completion",
  [",M"] = "dojo_bulk_completion",
}) do
  assert(input_keys[key][1] == action and input_keys[key].mode == "n", key .. " is Normal-mode only in the input")
  assert(list_keys[key][1] == action, key .. " also works in the result list")
  assert(type(picker.actions[action]) == "function", action .. " is defined")
end
assert(input_keys["<Tab>"][1] == "dojo_select" and list_keys["<Tab>"][1] == "dojo_select", "Tab selects without moving")
assert(input_keys.j[1] == "list_down" and input_keys.k[1] == "list_up", "j and k move through the results")
assert(input_keys[",n"] == nil and list_keys[",n"] == nil, "path resume is hidden without an active path")
for _, key in ipairs({ "i", "a", "v", "f", "<C-u>", "<C-d>" }) do
  assert(input_keys[key] == nil, "the picker leaves " .. key .. " to Vim and Snacks")
end

-- Rows: two utility rows, then every available task in catalogue order.
local items = picker.finder()
assert(items[1].guide and items[2].ideas, "the key guide and the idea backlog come first")
assert(#items == 2 + native.tasks + 1, "the default view hides the unavailable task")
assert(items[3].lesson.id == session.lessons()[1].id, "tasks keep the catalogue order")
for _, word in ipairs({ items[3].lesson.id, items[3].lesson.title, "drill", "vim", "native", "navigation" }) do
  assert(items[3].text:find(word, 1, true), "a row is searchable by " .. word)
end
assert(picker.format(items[1])[2][1] == "Picker key guide" and picker.format(items[2])[2][1] == "Task ideas")
local formatted = picker.format(items[3])
assert(formatted[1][1] == "  " and formatted[2][1] == "○ ", "a new task is unstarred and needs verification")
assert(formatted[3][1] == items[3].lesson.title and formatted[4][1]:find("drill · navigation", 1, true))

-- The count at the right of the input is shown/total over the whole catalogue.
do
  local buf = vim.api.nvim_create_buf(false, true)
  local shown = {
    input = {
      win = {
        buf = buf,
        valid = function()
          return true
        end,
      },
      update = function() end,
    },
    list = {
      selected = {},
      count = function()
        return 7
      end,
    },
  }
  local function totals()
    local namespace = vim.api.nvim_get_namespaces()["snacks.picker.input"]
    local mark = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })[1]
    return table.concat(vim.tbl_map(function(chunk)
      return chunk[1]
    end, mark[4].virt_text))
  end
  picker.on_show(shown)
  assert(totals() == ("7/%d "):format(#session.lessons() + 2), "the total counts hidden tasks and utility rows")
  shown.list.selected = { 1, 2 }
  shown.input:update()
  assert(totals() == ("(2) 7/%d "):format(#session.lessons() + 2), "a selection is counted in front")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Previews.
local guide = preview(picker, items[1])
assert(guide.title == "Picker key guide" and guide.ft == "markdown", "the key guide is a Markdown preview")
assert(guide.wo.wrap and guide.wo.linebreak and guide.wo.breakindent, "previews wrap at word boundaries")
for _, pattern in ipairs({
  ",f.*choose a facet filter",
  "Back to facets",
  ",x.*reset facets",
  ",n.*resume.*incomplete Entry",
  ",s.*star or unstar",
  ",v.*toggle verification",
  ",m.*toggle completion",
  "<Tab>.*select or unselect",
  ",M.*selected tasks.*shown tasks",
  ",i.*issue",
  ",a.*record a new task idea",
  "review.*issue",
  "verified and completed",
  "<C%-j>.*confirm",
  "<C%-k>.*disabled",
  "<C%-d>.*<C%-u>.*scroll the preview",
}) do
  assert(guide.text:find(pattern), "the key guide explains " .. pattern)
end
assert(preview(picker, items[2]).text:find("No ideas have been recorded yet", 1, true), "an empty backlog says so")
local probe = row(picker, "probe-available")
local shown = preview(picker, probe)
assert(shown.title == "Probe probe-available" and shown.ft == "markdown", "a task preview is titled by the task")
for _, line in ipairs({
  "- Kind: `lesson`",
  "- Topics: `probe-topic`",
  "- Source: `probe.nvim`",
  "- Binding: `custom`",
  "- Review: `new` at task revision 1",
  "- Completion: `incomplete`",
  "- Favourite: `no`",
  "- Practice: 0 passes from 0 attempts",
  "- Available: true (missing: none)",
  "## How",
  "1. Press `gx`.",
  "2. Then look.",
  "## Hint",
  "A probe hint.",
}) do
  assert(shown.text:find(line, 1, true), "a task preview shows: " .. line)
end
assert(not shown.text:find("Personal best", 1, true), "only a drill preview shows results")
assert(preview(picker, items[3]).text:find("- Personal best: `", 1, true), "a drill preview shows its personal best")

-- Facets. Each value narrows the rows; `all` removes only that facet.
ui.set_filter("availability", "unavailable")
assert(vim.deep_equal(ids(picker), { "probe-unavailable" }), "the unavailable view shows only unmet tasks")
local unavailable = row(picker, "probe-unavailable")
assert(picker.format(unavailable)[4][1]:find("unavailable", 1, true), "an unavailable row is labelled")
assert(
  preview(picker, unavailable).text:find("- Available: false (missing: capability:never)", 1, true),
  "the preview names the missing requirement"
)
ui.set_filter("availability", "all")
assert(#tasks(picker) == #session.lessons(), "availability:all shows every task")
ui.set_filter("source", "probe.nvim")
assert(#tasks(picker) == 2, "the source facet uses the plugin name")
ui.set_filter("source", "vim")
assert(#tasks(picker) == native.vim, "and the source kind otherwise")
ui.set_filter("source", "all")
ui.set_filter("binding", "custom")
assert(#tasks(picker) == 2, "the binding facet filters by origin")
ui.set_filter("binding", "all")
ui.set_filter("kind", "drill")
assert(#tasks(picker) == native.drills, "the kind facet separates drills from lessons")
ui.set_filter("topic", "navigation")
for _, item in ipairs(tasks(picker)) do
  assert(item.lesson.kind == "drill" and vim.tbl_contains(item.lesson.topics, "navigation"), "facets combine")
end
assert(#tasks(picker) == 3, "the three navigation drills")
assert(vim.deep_equal(ui.active_filters(), { kind = "drill", topic = "navigation" }), "active facets are readable")
assert(vim.deep_equal(state.filters(), { kind = "drill", topic = "navigation" }), "a facet is saved when it changes")
assert(open().win.list.title == "Tasks · topic:navigation · kind:drill", "facets are listed in a fixed order")
package.loaded["neovim_dojo.ui.snacks"] = nil
assert(require("neovim_dojo.ui.snacks").active_filters().topic == "navigation", "saved facets survive a reload")
package.loaded["neovim_dojo.ui.snacks"] = ui
assert(not pcall(ui.set_filter, "colour", "red"), "an unknown facet is refused")

-- `,x` restores the default view and updates the list title in place.
local cleared = handle()
picker.actions.dojo_clear_filters(cleared)
assert(vim.deep_equal(ui.active_filters(), { availability = "available" }), "clearing restores the default view")
assert(cleared.refreshes == 1 and cleared.titles[1] == "Tasks · availability:available")
assert(vim.deep_equal(state.filters(), { availability = "available" }), "and saves it")

-- The facet menu: a value, Back, Escape, and cancelling the first menu.
do
  local menus, answers = {}, {}
  vim.ui.select = function(values, options, choose)
    menus[#menus + 1] = { values = values, prompt = options.prompt }
    choose(answers[#menus])
  end
  local function filter(...)
    menus, answers = {}, { ... }
    local closing, count = handle(), #opened
    picker.actions.dojo_filter(closing)
    reopened(count + 1, "the catalogue reopens after the facet menu")
    assert(closing.closes == 1, "the facet menu replaces the catalogue")
  end
  filter("kind", "lesson")
  assert(
    menus[1].prompt == "Filter Neovim Dojo by facet"
      and vim.deep_equal(
        menus[1].values,
        { "path", "topic", "source", "binding", "kind", "review", "completion", "availability" }
      ),
    "the first menu lists the facets"
  )
  assert(
    menus[2].prompt == "Filter kind"
      and vim.deep_equal(menus[2].values, { "← Back to facets", "all", "drill", "lesson" }),
    "a value menu starts with Back and all"
  )
  assert(ui.active_filters().kind == "lesson" and opened[#opened].win.list.title:find("kind:lesson", 1, true))
  filter("kind", "all")
  assert(ui.active_filters().kind == nil, "choosing all removes that facet")
  filter("path", "← Back to facets", "review", nil, nil)
  assert(#menus == 5 and menus[5].prompt == "Filter Neovim Dojo by facet", "Back and Escape return to the facets")
  local path_values = { "← Back to facets", "all" }
  for _, path in ipairs(session.paths()) do
    path_values[#path_values + 1] = path.id
  end
  assert(vim.deep_equal(menus[2].values, path_values), "the path menu lists every path in order")
  assert(vim.deep_equal(menus[4].values, { "← Back to facets", "new", "changed", "verified", "issue", "all" }))
  filter("completion", "complete")
  assert(vim.deep_equal(menus[2].values, { "← Back to facets", "incomplete", "complete", "all" }))
  filter("availability", "all")
  assert(vim.deep_equal(menus[2].values, { "← Back to facets", "available", "unavailable", "all" }))
  assert(vim.deep_equal(ui.active_filters(), { completion = "complete" }), "facet choices accumulate")
  ui.reset_filters()
  vim.ui.select = original_select
end

-- Favourite, completion and verification, and the marker they produce.
local first = items[3]
local function marker(id)
  return picker.format(row(picker, id))[2][1]
end
local last = tasks(picker)[#tasks(picker)]
local acting = handle()
picker.actions.dojo_favorite(acting, last)
assert(acting.refreshes == 1 and last_notice().message == "Lesson starred", "starring refreshes the rows")
local starred = picker.finder()[3]
assert(starred.lesson.id == last.lesson.id and picker.format(starred)[1][1] == "★ ", "a favourite sorts first")
assert(starred.text:find("favourite", 1, true), "and is searchable as one")
assert(preview(picker, starred).text:find("- Favourite: `yes`", 1, true))
assert(session.clear_progress(true) and session.lesson_state(last.lesson).favorite, "a progress reset keeps stars")
picker.actions.dojo_favorite(acting, starred)
assert(last_notice().message == "Lesson unstarred" and picker.finder()[3].lesson.id == first.lesson.id)

picker.actions.dojo_completion(acting, first)
assert(last_notice().message == "Task marked complete" and acting.titles[1] == "Tasks · availability:available")
assert(
  session.lesson_state(first.lesson).completed and session.lesson_state(first.lesson).passes == 0,
  "no pass is invented"
)
assert(marker(first.lesson.id) == "○ ", "an unverified task asks for verification even when complete")
ui.set_filter("completion", "complete")
assert(vim.deep_equal(ids(picker), { first.lesson.id }), "the complete view shows only completed tasks")
ui.set_filter("completion", "incomplete")
assert(not vim.tbl_contains(ids(picker), first.lesson.id) and #tasks(picker) == native.tasks)
ui.set_filter("completion", "all")
picker.actions.dojo_verify(acting, row(picker, first.lesson.id))
assert(last_notice().message == "Task revision verified" and marker(first.lesson.id) == "✓ ", "verified and complete")
ui.set_filter("review", "verified")
assert(vim.deep_equal(ids(picker), { first.lesson.id }), "the review facet finds verified tasks")
ui.set_filter("review", "new")
assert(not vim.tbl_contains(ids(picker), first.lesson.id))
ui.set_filter("review", "all")
picker.actions.dojo_completion(handle({ list = false }), row(picker, first.lesson.id))
assert(last_notice().message == "Task marked incomplete" and marker(first.lesson.id) == "◇ ", "verified, incomplete")
first.lesson.revision = first.lesson.revision + 1
assert(marker(first.lesson.id) == "↻ ", "a raised revision asks for another look")
ui.set_filter("review", "changed")
assert(vim.deep_equal(ids(picker), { first.lesson.id }))
ui.set_filter("review", "all")
first.lesson.revision = first.lesson.revision - 1
picker.actions.dojo_verify(acting, row(picker, first.lesson.id))
assert(last_notice().message == "Task marked unverified" and marker(first.lesson.id) == "○ ", "verification toggles")
local before = acting.refreshes
for _, action in ipairs({ "dojo_favorite", "dojo_completion", "dojo_verify", "dojo_issue" }) do
  picker.actions[action](acting, items[1])
  picker.actions[action](acting, nil)
end
assert(acting.refreshes == before and acting.closes == 0, "task actions ignore the utility rows")

-- Issues: report, edit, cancel and remove.
do
  local prompts, answer = {}, nil
  vim.ui.input = function(options, done)
    prompts[#prompts + 1] = options
    done(answer)
  end
  local function issue(text)
    answer = text
    local closing, count = handle(), #opened
    picker.actions.dojo_issue(closing, row(picker, "probe-available"))
    reopened(count + 1, "the catalogue reopens after the issue prompt")
    assert(closing.closes == 1)
  end
  issue("  The goal is unclear.  ")
  assert(prompts[1].prompt == "Report issue: " and prompts[1].default == nil)
  assert(last_notice().message == "Lesson issue recorded" and marker("probe-available") == "! ", "an issue is marked")
  local reported = preview(picker, row(picker, "probe-available")).text
  assert(reported:find("## Reported issue", 1, true) and reported:find("\nThe goal is unclear.\n", 1, true))
  ui.set_filter("review", "issue")
  assert(vim.deep_equal(ids(picker), { "probe-available" }), "review:issue lists reported tasks")
  ui.set_filter("review", "all")
  issue("It needs an example.")
  assert(prompts[2].prompt == "Edit issue (empty removes): " and prompts[2].default == "The goal is unclear.")
  assert(last_notice().message == "Lesson issue updated")
  assert(preview(picker, row(picker, "probe-available")).text:find("It needs an example.", 1, true))
  issue(nil)
  assert(
    marker("probe-available") == "! " and last_notice().message == "Lesson issue updated",
    "Escape changes nothing"
  )
  issue("  ")
  assert(
    last_notice().message == "Lesson issue removed" and marker("probe-available") == "○ ",
    "empty text removes it"
  )
  vim.ui.input = original_input
end

-- Ideas keep the task, the search text and the facets they were recorded with.
do
  local answers, asked = {}, 0
  vim.ui.input = function(_, done)
    asked = asked + 1
    done(answers[asked])
  end
  local function idea(...)
    answers, asked = { ... }, 0
    local closing = handle({
      filter = function()
        return { pattern = "splits" }
      end,
    })
    local count = #opened
    picker.actions.dojo_idea(closing, row(picker, "balance-splits"))
    reopened(count + 1, "the catalogue reopens after an idea")
    assert(closing.closes == 1)
  end
  idea("  ")
  assert(asked == 1 and vim.fn.filereadable(ideas_path) == 0, "an empty title records nothing")
  ui.set_filter("topic", "windows")
  idea(" Teach resizing ", " With counts. ")
  ui.set_filter("topic", "all")
  local written = table.concat(vim.fn.readfile(ideas_path), "\n")
  for _, line in ipairs({
    "## Teach resizing",
    "- Context task: `balance-splits`",
    "- Search: `splits`",
    "- Facets: `availability:available`, `topic:windows`",
    "\nWith counts.",
  }) do
    assert(written:find(line, 1, true), "the idea file has: " .. line)
  end
  assert(last_notice().message == "Dojo idea recorded")
  assert(preview(picker, items[2]).text:find("## Teach resizing", 1, true), "the Task ideas row previews the file")
  vim.ui.input = original_input
end

-- Bulk completion sets the selected tasks, or else every shown task.
do
  local prompt, answer
  vim.ui.select = function(values, options, choose)
    assert(vim.deep_equal(values, { "incomplete", "complete" }), "bulk completion is a set operation")
    prompt = options.prompt
    choose(answer)
  end
  local pair = { items[3], items[4] }
  local function bulk(choice, selected, shown_items)
    answer = choice
    local closing = handle({
      selected = function()
        return selected
      end,
      items = function()
        return assert(shown_items, "a selection must not read the shown rows")
      end,
    })
    local count = #opened
    picker.actions.dojo_bulk_completion(closing)
    reopened(count + 1, "the catalogue reopens after a bulk change")
    assert(closing.closes == 1)
  end
  local function completed(item)
    return session.lesson_state(item.lesson).completed
  end
  assert(session.verify(pair[1].lesson), "a review state to preserve")
  bulk("complete", pair)
  assert(prompt == "Set 2 selected tasks" and completed(pair[1]) and completed(pair[2]))
  assert(last_notice().message == "Set 2 tasks complete")
  bulk(nil, pair)
  assert(completed(pair[1]) and completed(pair[2]), "cancelling changes nothing")
  bulk("incomplete", {}, { items[1], items[2], pair[1], pair[2], pair[1] })
  assert(prompt == "Set 2 shown tasks", "utility rows and repeated rows are not counted")
  assert(not completed(pair[1]) and not completed(pair[2]) and last_notice().message == "Set 2 tasks incomplete")
  assert(session.review_status(pair[1].lesson) == "verified", "bulk completion keeps the review state")
  assert(session.verify(pair[1].lesson))
  local nothing = handle({
    selected = function()
      return {}
    end,
    items = function()
      return { items[1], items[2] }
    end,
  })
  picker.actions.dojo_bulk_completion(nothing)
  assert(nothing.closes == 0 and last_notice().message == "No tasks selected or shown", "nothing to set is reported")
  vim.ui.select = original_select
end

-- Selection is delegated to the Snacks list.
do
  local selections = 0
  picker.actions.dojo_select({
    list = {
      select = function()
        selections = selections + 1
      end,
    },
  })
  assert(selections == 1)
end

-- A path orders the rows, shows progress and adds the resume key.
ui.set_filter("path", "probe-path")
local path_picker = open()
assert(path_picker.win.list.title == "Tasks · path:Probe path · availability:available · 0/2 complete")
assert(path_picker.title:find(",n: resume path", 1, true), "an active path advertises resume")
assert(
  path_picker.win.input.keys[",n"][1] == "dojo_next_path_entry"
    and path_picker.win.list.keys[",n"][1] == "dojo_next_path_entry",
  "resume works from both picker windows"
)
assert(vim.deep_equal(ids(path_picker), { "balance-splits", "probe-available" }), "a path uses its own order")
assert(#path_picker.finder() == 4, "the utility rows stay with a path")
local entry = row(path_picker, "probe-available")
assert(entry.path_position == 2 and path_picker.format(entry)[4][1]:find("path 2/2", 1, true))
assert(preview(path_picker, entry).text:find("- Path: `Probe path` (2/2)", 1, true))
session.toggle_favorite(entry.lesson)
assert(vim.deep_equal(ids(path_picker), { "balance-splits", "probe-available" }), "a star does not reorder a path")
session.toggle_favorite(entry.lesson)
local progress = handle()
path_picker.actions.dojo_completion(progress, row(path_picker, "balance-splits"))
assert(progress.titles[1]:find("1/2 complete", 1, true), "path progress follows completion")
ui.set_filter("completion", "incomplete")
assert(open().win.list.title:find("1/2 complete", 1, true), "progress covers the whole path, not the shown rows")
ui.set_filter("completion", "all")
local resume = handle()
path_picker.actions.dojo_next_path_entry(resume)
assert(
  vim.wait(1000, function()
    return vim.api.nvim_buf_get_name(0) == "neovim-dojo://probe-available"
  end),
  "resume starts the first incomplete entry"
)
assert(resume.closes == 1 and vim.fn.maparg(",n", "n") ~= "", "a path task has its own next key")
session.quit()
path_picker.actions.dojo_completion(progress, row(path_picker, "probe-available"))
local done = open()
assert(done.title:find("path complete · ,M: reset shown", 1, true), "a finished path says how to restart it")
local finished = handle()
done.actions.dojo_next_path_entry(finished)
assert(finished.closes == 0 and last_notice().message:find("Path complete: Probe path", 1, true))
assert(last_notice().level == vim.log.levels.WARN, "the path-complete message must not be hidden as INFO")
session.clear_progress(true)
ui.reset_filters()

-- Confirm: utility rows, an unavailable task, and a task inside a path.
local confirming = handle()
picker.confirm(confirming, nil)
picker.confirm(confirming, items[1])
assert(confirming.closes == 0, "the key guide is read in the preview, not opened")
picker.confirm(confirming, unavailable)
assert(confirming.closes == 0 and last_notice().message == "Lesson unavailable: capability:never")
picker.confirm(confirming, row(picker, "balance-splits"))
assert(
  vim.wait(1000, function()
    return vim.api.nvim_buf_get_name(0) == "neovim-dojo://balance-splits"
  end),
  "Enter starts the task"
)
assert(confirming.closes == 1 and vim.fn.maparg(",n", "n") == "", "outside a path there is no next key")
session.quit()
picker.confirm(handle(), entry)
assert(vim.wait(1000, function()
  return vim.api.nvim_buf_get_name(0) == "neovim-dojo://probe-available"
end))
assert(vim.fn.maparg(",n", "n") ~= "", "a task started from a path row keeps its path")
session.quit()
picker.confirm(handle(), items[2])
assert(
  vim.wait(1000, function()
    return vim.api.nvim_buf_get_name(0) == ideas_path
  end),
  "Enter on Task ideas opens the idea file"
)
vim.cmd("bwipeout!")

-- The prefix option moves every picker key and the text that names them.
dojo.setup({ curricula = { "native", pack }, prefix = "<localleader>", ideas_path = ideas_path })
ui.set_filter("path", "probe-path")
local prefixed = open()
assert(prefixed.win.input.keys["<localleader>f"][1] == "dojo_filter" and prefixed.win.input.keys[",f"] == nil)
assert(prefixed.win.list.keys["<localleader>n"][1] == "dojo_next_path_entry")
assert(prefixed.title:find("<localleader>f: filter · <localleader>n: resume path", 1, true))
assert(preview(prefixed, prefixed.finder()[1]).text:find("- `<localleader>M`: set selected tasks", 1, true))
ui.reset_filters()

-- Without an idea file there is one utility row.
dojo.setup({ curricula = { "native", pack } })
local plain = open()
assert(plain.finder()[1].guide and plain.finder()[2].lesson, "the Task ideas row needs an idea file")
plain.on_show({
  input = {
    win = {
      buf = 0,
      valid = function()
        return false
      end,
    },
    update = function() end,
  },
  list = { selected = {}, count = function() end },
})

vim.fn.delete(vim.fs.dirname(ideas_path), "rf")
session.clear_progress(true)
ui.reset_filters()
_G.Snacks, vim.notify = original_snacks, original_notify
print("DOJO PICKER OK")
