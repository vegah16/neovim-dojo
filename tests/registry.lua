-- The catalogue contract: the built-in pack, topic extension, overrides,
-- paths and the configurable control prefix.
local dojo = require("neovim_dojo")
dojo.setup()
local session, registry = dojo.session, dojo.registry

local counts, ids = { lesson = 0, drill = 0 }, {}
for _, task in ipairs(session.lessons()) do
  assert(task.id:match("^[a-z0-9][a-z0-9-]*$") and not task.id:find("--", 1, true), "stable kebab-case ID: " .. task.id)
  assert(not ids[task.id], "duplicate task ID")
  ids[task.id] = true
  assert(task.revision >= 1 and task.revision % 1 == 0, "positive revision: " .. task.id)
  assert(
    type(task.objective) == "string" and task.objective ~= "" and #task.steps > 0,
    "teaching contract: " .. task.id
  )
  assert(
    task.source.kind == "vim" or task.source.kind == "neovim",
    "the native pack teaches only Vim and Neovim: " .. task.id
  )
  assert(task.bindings.origin == "native", "the native pack uses only native keys: " .. task.id)
  assert(#(task.requires.plugins or {}) == 0, "the native pack needs no plugin: " .. task.id)
  local text = table.concat(vim.list_extend({ task.objective, task.hint or "" }, task.steps), "\n")
  assert(not text:find("<leader>", 1, true), "the native pack names no leader mapping: " .. task.id)
  for _, capability in ipairs(task.requires.capabilities or {}) do
    assert(session.options.capabilities[capability], task.id .. ": undeclared capability " .. capability)
  end
  if task.curriculum == "native" and vim.fn.executable("git") == 1 then
    assert(session.availability(task), "a native task must be available in a stock editor: " .. task.id)
  end
  counts[task.kind] = counts[task.kind] + 1
  if task.drill and task.drill.kind == "scenarios" then
    for _, scene in ipairs(task.drill.scenes) do
      assert(not vim.deep_equal(scene.lines, scene.check.lines), "a scene must require a change or additional state")
    end
  end
end
assert(
  counts.lesson == 39 and counts.drill == 20,
  ("native pack size changed: %d lessons, %d drills"):format(counts.lesson, counts.drill)
)
assert(#session.topics() == 14 and #session.paths() == 1, "fourteen topics and the Fundamentals path")
local fundamentals = session.find_path("neovim-fundamentals")
assert(#fundamentals.entries == 10 and fundamentals.revision == 1, "Fundamentals membership is stable")
for _, id in ipairs(fundamentals.entries) do
  assert(ids[id], "path entry must resolve: " .. id)
end
for _, file in ipairs(vim.fn.glob("lua/neovim_dojo/**/*.lua", false, true)) do
  assert(loadfile(file))
end
assert(vim.tbl_contains(session.find_lesson("counted-word-ends").keywords, "3e"), "quoted teaching keys are searchable")
print(("DOJO NATIVE PACK OK: %d lessons, %d drills, 14 topics, 1 path"):format(counts.lesson, counts.drill))

-- A second curriculum extends a topic, overrides a task and adds a path.
local function pack()
  return {
    id = "probe-pack",
    topics = {
      {
        id = "windows", -- registered by the native pack
        source = { kind = "plugin", name = "probe.nvim" },
        requires = { plugins = { "probe.nvim" } },
        bindings = { origin = "custom" },
        lessons = {
          {
            id = "probe-extension-task",
            title = "Probe",
            objective = "Use `probe-key`.",
            steps = { "A probe." },
            topics = { "extra-topic" },
            keywords = { "explicit-key" },
            lines = { "fixture" },
            check = { kind = "manual" },
          },
        },
      },
    },
    overrides = {
      ["create-vertical-split"] = {
        steps = { "Press `<C-w>v`, or this config's `<leader>|`." },
        bindings = { origin = "mixed" },
      },
    },
    paths = {
      {
        id = "probe-path",
        revision = 1,
        title = "Probe",
        description = "Mixed.",
        entries = { "balance-splits", "probe-extension-task" },
      },
    },
  }
end
local native_split = vim.deepcopy(session.find_lesson("create-vertical-split").steps)
dojo.setup({ curricula = { "native", pack() }, prefix = "<localleader>" })
local windows = session.find_topic("windows")
assert(windows.title == "Windows" and windows.curriculum == "native", "an extended topic keeps its first definition")
assert(#windows.lessons == 4 and windows.lessons[4].id == "probe-extension-task", "new tasks join the existing topic")
local probe = session.find_lesson("probe-extension-task")
assert(probe.curriculum == "probe-pack" and probe.source.name == "probe.nvim", "an extension uses its own defaults")
assert(vim.tbl_contains(probe.topics, "windows") and vim.tbl_contains(probe.topics, "extra-topic"), "topics are merged")
assert(
  vim.tbl_contains(probe.keywords, "explicit-key") and vim.tbl_contains(probe.keywords, "probe-key"),
  "nil parent keywords must preserve explicit and quoted keys"
)
local available, missing = session.availability(probe)
assert(not available and missing[1] == "plugin:probe.nvim", "a missing plugin makes its task unavailable")
local split = session.find_lesson("create-vertical-split")
assert(split.steps[1]:find("<leader>|", 1, true) and #split.steps == 1, "an override replaces the named fields whole")
assert(split.bindings.origin == "mixed" and split.curriculum == "native", "and keeps the task's identity")
assert(split.check.kind == "window_count" and windows.lessons[1] == split, "its other fields and position are kept")
assert(vim.tbl_contains(split.keywords, "<leader>|"), "overridden text is indexed again")
assert(#session.lessons() == 60 and #session.find_path("probe-path").entries == 2, "one task and one path were added")
dojo.setup()
assert(
  vim.deep_equal(session.find_lesson("create-vertical-split").steps, native_split),
  "setup starts from a clean registry"
)
for _, bad in ipairs({
  { id = "bad", overrides = { ["no-such-task"] = { steps = { "x" } } } },
  { id = "bad", overrides = { ["balance-splits"] = { id = "renamed" } } },
  { id = "bad", paths = { { id = "p", revision = 1, title = "P", description = "D", entries = { "no-such-task" } } } },
  { id = "bad", topics = { { id = "t", title = "T", lessons = { { id = "balance-splits", title = "Duplicate" } } } } },
}) do
  assert(not pcall(dojo.setup, { curricula = { "native", bad } }), "an invalid curriculum must be refused")
end
assert(not pcall(dojo.setup, { curricula = { "no-such-pack" } }), "an unknown built-in pack must be refused")
print("DOJO CURRICULUM EXTENSION OK")

-- Control keys follow the configured prefix, in mappings and in text.
local controls = require("neovim_dojo.controls")
dojo.setup({ prefix = "<localleader>" })
assert(
  controls.text("Press `,k` to check, then ,r (or `,M`). Keep a, b and `x,y`.")
    == "Press `<localleader>k` to check, then <localleader>r (or `<localleader>M`). Keep a, b and `x,y`.",
  "only control keys are rewritten"
)
assert(session.start("balance-splits"))
assert(vim.fn.maparg("<localleader>r", "n", false, true).desc == "Reset task", "controls use the configured prefix")
assert(vim.fn.maparg(",r", "n") == "", "and leave the default prefix alone")
session.quit()
dojo.setup()
assert(controls.text("Press `,k`.") == "Press `,k`.", "the default prefix needs no rewriting")
assert(session.start("balance-splits"))
assert(vim.fn.maparg(",r", "n", false, true).desc == "Reset task", "the default prefix is a comma")
session.quit()
session.clear_progress(true)
print("DOJO CONTROL PREFIX OK")
