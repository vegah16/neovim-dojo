# neovim-dojo

An interactive handbook and training ground inside Neovim. A **lesson** explains
one thing and checks that you did it. A **drill** repeats one movement until it
is a habit, and keeps your last time and your best.

Every task runs in a throwaway buffer or a throwaway project, so nothing you
practise touches your own files.

The plugin has two parts:

- an **engine**: the task runner, the checks, the drill runners, progress and
  review state, and a picker;
- **curriculum packs**: plain Lua tables of tasks. One pack is built in. It
  teaches native Vim and Neovim only and works in a stock editor: motions,
  Insert mode, operators, text objects, Visual mode, registers, search, Ex
  commands, macros, folds, windows, buffers, quickfix and diff mode. Three
  learning paths order it from beginner to advanced. You add your own pack to
  teach your plugins and your key mappings.

## Requirements

- Neovim 0.11.5 or newer. The tests run on 0.11.5 and 0.12.
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim). With its picker
  you get fuzzy search, filters and a preview. Without it the Dojo uses
  `vim.ui.select`.
- Optional: `git`, for file-backed tasks that need a repository.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "vegah16/neovim-dojo",
  cmd = { "NeovimDojo", "NeovimDojoReset", "NeovimDojoIdea", "NeovimDojoIdeas" },
  opts = {},
}
```

With another plugin manager, install the repository and call
`require("neovim_dojo").setup()`.

Then run `:NeovimDojo`.

## Use

| Command | Action |
| --- | --- |
| `:NeovimDojo` | Open the task list |
| `:NeovimDojo {id}` | Start one task; the ID completes with `<Tab>` |
| `:NeovimDojoReset` | Clear practice progress, after a confirmation (`!` skips it) |
| `:NeovimDojoIdea [title]` | Write down an idea for a new task |
| `:NeovimDojoIdeas` | Open the idea file, when `ideas_path` is set |

A task opens in a new tab. The panel above the text shows the goal, the steps,
the controls and the status. Controls start with the prefix, a comma by default:

| Key | Action |
| --- | --- |
| `,h` | Show the hint (in a drill: the full instructions) |
| `,r` | Reset the fixture for another attempt |
| `,m` | Mark the task complete or incomplete |
| `,s` | Star the task |
| `,v` | Mark this revision of the task as verified by you |
| `,i` | Report, edit or remove an issue with the task |
| `,n` | Start the next task of the learning path |
| `,c` | Back to the task list |
| `,q` | Quit the task and remove its buffers and files |
| `<CR>` | Start or replay a drill |
| `,k` | Check the current round of an untimed drill |

A lesson completes by itself when its outcome is reached. Lessons that only ask
you to look at something are completed by hand with `,m`.

The comma shadows Vim's own `,` (repeat `f`/`t` backwards) inside a task. Set
`prefix` if you want another key.

With snacks.nvim, the task list has the same keys plus `,f` to filter by a facet
(path, topic, source, binding, kind, review, completion, availability), `,x` to
clear the filters, `,M` to set completion for many tasks and `,a` to record an
idea. The first row of the list is the full key guide.

### What is stored

Progress is one JSON file, `stdpath("state")/neovim-dojo.json`: attempts,
passes, completion, drill results, stars, review state and the chosen filters.
It never leaves your machine.

Review state is separate from progress. `,v` says "I have checked that this
task, at this revision, teaches what it claims". When a task's `revision` goes
up, the task shows as changed until you verify it again.

## Configure

All options, with their defaults:

```lua
require("neovim_dojo").setup({
  -- Curriculum tables, or the name of a built-in pack. Later packs may add
  -- tasks to earlier topics and override earlier tasks.
  curricula = { "native" },

  -- Prefix of the control keys in a task and in the picker.
  prefix = ",",

  -- Global mappings. None by default.
  mappings = { open = nil, reset = nil, idea = nil },

  -- Named requirement tests. A task that lists a capability is unavailable
  -- while its test returns false. `git` is predefined.
  capabilities = {},

  -- Markdown file that receives task ideas. Without it, ideas are kept in the
  -- state file.
  ideas_path = nil,

  -- Custom task setups and checks, by `kind`; see "Custom setups and checks".
  setups = {},
  checkers = {},
  -- Custom drill runners, by `kind`.
  drills = {},

  -- Hooks. Each receives the session context.
  before_reset = nil,   -- function(context)
  before_quit = nil,    -- function(context)
  on_event = nil,       -- function(context, event)
  on_mappings = nil,    -- function(buf, context): after controls are mapped

  -- Replace the picker: a table with open(session).
  ui = nil,
  -- Replace the availability test: function(task) -> boolean, missing[]
  requirements = nil,
})
```

`setup()` may be called again; it rebuilds the catalogue from scratch.
`require("neovim_dojo").register(pack)` adds one pack later.

## Write a pack

A pack is a table with an `id`, a list of topics, and optionally learning paths
and overrides:

```lua
local pack = {
  id = "my-config",
  title = "My config",
  topics = {
    {
      id = "surround",
      title = "Surround",
      description = "Add, change and delete pairs.",
      -- Defaults for every task of this pack in this topic:
      source = { kind = "plugin", name = "nvim-surround" },
      requires = { plugins = { "nvim-surround" } },
      bindings = { origin = "plugin-default" },
      lessons = {
        {
          id = "surround-word",
          revision = 1,
          title = "Surround a word",
          objective = "Put double quotes around `target`.",
          steps = { "With the cursor on `target`, type `ysiw\"`." },
          hint = "`ys` takes any motion or text object.",
          lines = { "Wrap the target word." },
          cursor = { 1, 9 },
          cues = { { line = 1, text = "target" } },
          check = { kind = "buffer_equals", lines = { 'Wrap the "target" word.' } },
        },
      },
    },
  },
}

require("neovim_dojo").setup({ curricula = { "native", pack } })
```

### Task fields

| Field | Meaning |
| --- | --- |
| `id` | Unique, stable, kebab-case. Progress is stored under it, so never reuse or rename one |
| `revision` | Raise it when a person should look at the task again. Drill results are kept per revision |
| `kind` | `"lesson"` (default) or `"drill"` |
| `title`, `objective`, `steps`, `hint` | The teaching text. Put keys and literal text in backticks: they are highlighted, and indexed for search |
| `topics` | Extra topic names for filtering |
| `source` | `{ kind = "vim" \| "neovim" \| "plugin" \| "config", name = ... }` |
| `bindings` | `{ origin = "native" \| "plugin-default" \| "custom" \| "mixed" }` |
| `requires` | `{ plugins = {...}, parsers = {...}, capabilities = {...} }`. An unmet requirement hides the task and says why |
| `keywords` | Extra search terms |
| `filetype`, `lines`, `cursor` | The fixture: buffer filetype (default `text`), its text, and the start position `{ line, column }` |
| `options` | Buffer or window options the task depends on, for example `{ shiftwidth = 2 }` |
| `cues` | Text to highlight as the target: `{ line = 1, text = "word" }` |
| `preserve_registers` | Registers the task may change. They are restored when it closes |
| `setup` | `{ kind = ... }`: a built-in or custom fixture setup |
| `check` | `{ kind = ... }`: when the lesson counts as done |
| `drill` | For drills: `{ kind = ..., rounds = ..., ... }` |

A plugin requirement is the plugin's directory name, such as `flash.nvim`. It is
met when lazy.nvim knows the plugin or the directory is on the runtime path or
in a package directory.

A check runs after every edit and cursor move. It must not be true after only
the first step. Check the outcome, not one exact key sequence.

Built-in checks:

| `check.kind` | Passes when |
| --- | --- |
| `outcome` | Every declared field matches; see below |
| `buffer_equals` | The buffer equals `lines` |
| `buffer_equals_at_cursor` | The buffer equals `lines` and the cursor is at `cursor` |
| `cursor_on_text` | The cursor is on `text` in `line` |
| `cursor_round_trip` | The cursor visited `target` and came back to `origin`; optionally with a `mark` set |
| `window_count`, `equal_window_widths` | The task buffer is shown in at least `minimum` windows (of equal width) |
| `target_window`, `target_buffer`, `window_narrower` | The window or buffer that the matching setup marked was reached or resized |
| `undo_branch` | The buffer equals `lines` and the undo tree has a second branch |
| `cmdwin_types`, `cmdwin_text` | The command-line window was opened for these `types`, or with this `text` |
| `workspace` | A file-backed outcome; see below |
| `manual` | Never; the learner presses `,m` |

The fields of an `outcome` check. Declare only what the lesson is about:

| Field | Passes when |
| --- | --- |
| `lines` | The buffer holds exactly these lines |
| `cursor` | The cursor is at `{ line, column }` in the task buffer |
| `mark` | Mark `name` is at `position` |
| `register` | Register `name` equals `value`, or contains `contains` |
| `search` | The last search pattern is exactly this string |
| `search_accepts`, `search_rejects` | The last search pattern matches every string of the first list and none of the second. Prefer these to `search` when several spellings are right |
| `repeat_contains` | The text of the last insert contains this string |
| `folds` | The lines in `closed` are inside a closed fold and the lines in `open` are not |
| `winline` | `"top"`: the cursor line is as high in the window as 'scrolloff' allows |
| `extra` | Your function `extra(context)` returns true. It runs on every check, so it may remember what it saw in `context` |

`search`, `search_accepts`, `search_rejects` and `repeat_contains` only add to
another field: a search pattern survives from one task to the next.

A task's `options` are applied when it starts and again on every reset.

Built-in setups: `clear_undo_history`, `buffer_navigation` (extra listed
buffers), `unequal_vertical_splits`, `native_window_navigation`,
`resize_vertical_splits` and `project`.

### Drills

A drill names a runner and its workload:

```lua
{
  id = "hjkl-target-grid",
  kind = "drill",
  title = "Reach targets with hjkl",
  objective = "Reach ten highlighted targets using only `h`, `j`, `k`, and `l`.",
  steps = { "Press `<CR>` when you are ready." },
  drill = { kind = "cursor_targets", rounds = 10, rows = 11, columns = 25, distance = 6 },
}
```

| `drill.kind` | Rounds of |
| --- | --- |
| `cursor_targets` | Reaching a target on a grid, always the same distance away |
| `text_actions` | One edit per round. `variant`: `relative_line`, `odd_word`, `change_inside`, `marked_case`, `move_visual_line`, `character_motion`, `register_recall`, `macro_lines`. For `character_motion`, `repeat_keys = { F = "f" }` names the key that repeats a motion where it is not the motion key itself |
| `search_targets` | Reaching a highlighted word among distractors, for search and jump tools |
| `window_targets` | Reaching a target in another window |
| `remote_actions` | Deleting, yanking or changing distant text and returning |
| `syntax_nodes` | Removing a highlighted syntax node |
| `undo_branches` | Recovering text from an abandoned undo branch |
| `scenarios` | Untimed outcomes: each scene has a `goal`, `lines` and a `check`, optionally a `cursor` and `options`, and the learner checks with `,k` |

Timed runners use a fixed workload per run, so that a personal best means
something: the order is random, the total distance or number of edits is not.
Raise the task's `revision` when you change the workload.

`require("neovim_dojo.author")` has two helpers for the common cases:
`lesson(id, title, objective, steps, lines, check, options)` for an outcome
lesson and `drill(id, title, objective, steps, scenes, options)` for a scenario
drill. Look at `lua/neovim_dojo/packs/native/` for complete examples.

### Learning paths

A path is an ordered list of task IDs. It may name tasks from any pack.

```lua
paths = {
  {
    id = "my-first-week",
    revision = 1,
    title = "My first week",
    description = "Movement first, then the plugins I use every day.",
    entries = { "hjkl-target-grid", "counted-word-ends", "surround-word" },
  },
}
```

Choosing a path in the picker shows its tasks in order with `done/total`.
`,n` starts the first incomplete entry. A path does not store progress of its
own.

The built-in pack has four paths. `neovim-fundamentals` is a short first tour.
`native-first-steps`, `native-fluent-editing` and `native-power-tools` are
three levels that together hold every built-in task exactly once.

### Extend a built-in topic, or change a built-in task

A topic ID that an earlier pack registered is extended: your tasks join that
topic, with your own defaults for `source`, `requires` and `bindings`.

`overrides` replaces fields of an earlier task. Use it when your configuration
changes what a native lesson should say:

```lua
overrides = {
  ["create-vertical-split"] = {
    steps = { "Type `<C-w>v`, or `<leader>|` in this config." },
    bindings = { origin = "mixed" },
  },
}
```

A field in an override replaces the original field whole. The task keeps its
ID, its topic, its position and its stored progress.

### Capabilities

A capability is a named test for something that is not a plugin: a program, a
language server, a running session.

```lua
capabilities = {
  python = function() return vim.fn.executable("python3") == 1 end,
}
-- in a task: requires = { capabilities = { "python" } }
```

### Custom setups and checks

`setups[kind](context, setup)` prepares a fixture and `checkers[kind](context,
check)` returns true when the lesson is done. The context holds `buf`, `tab`,
`lesson`, and for file-backed tasks `project_root` and `workspace`.

```lua
setups = {
  two_tabs = function(context) vim.cmd.tabnew() end,
},
checkers = {
  inlay_hints_enabled = function(context)
    return vim.lsp.inlay_hint.is_enabled({ bufnr = context.buf })
  end,
},
```

### File-backed tasks

`setup.kind = "project"` gives the task a private temporary directory with real
files, and optionally a Git repository with one baseline commit. The directory
is removed when the task closes. `require("neovim_dojo.workspace")` has the
helpers:

```lua
local w = require("neovim_dojo.workspace")

w.lesson(
  "rename-the-helper",
  "Rename across two files",
  "Rename `old_name` to `new_name` in both files.",
  { "Use your LSP rename, or `:cdo`." },
  { "from helper import old_name" },                       -- main file
  { files = { ["helper.py"] = { "def new_name(): pass" } } }, -- outcome
  { entry = "main.py", files = { ["helper.py"] = { "def old_name(): pass" } }, git = true }
)
```

A `workspace` check can require file contents (`files`, with `disk = true` to
read the saved file), missing paths (`absent`), directories (`dirs`), the
current file and cursor (`position`), visited files (`visited`), a window
`layout`, the tab directory (`tcd`), and a function of your own (`extra`).
`layout` counts ordinary windows only; in a function of your own, use
`w.windows(context)` for the same list without floating windows.
`w.drill(...)` makes a scenario drill over the same kind of fixture.
`setup.prepare(context, scene)` and `setup.after_read(context, scene)` run your
own code while a scene is built. Put clean-up in `context.workspace.cleanup`.

Plugins that hold state for a directory need to let go of it when the fixture
goes away. Tell the workspace how, once:

```lua
w.extend({
  name = "oil",
  cleanup = function(context)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name:sub(1, 6) == "oil://" and w.owns(context, (name:sub(7):gsub("/$", ""))) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end,
})
```

An extension may also have `observe(context, event)` to record what the learner
did, `check(context, check)` to add outcome fields (return `false` to refuse),
and `models[name](context, scene)` to prepare scenes whose `model` is `name`.

The task controls are mapped in the task's own buffer and in every ordinary
file buffer inside the fixture. A plugin's own buffer (one with a `buftype`,
such as a search panel) keeps its keys, also when its name resolves into the
fixture.

`require("neovim_dojo.session").owns_path(path)` is true for any path inside a
fixture that this editor session created. Use it to keep other tools, such as a
test runner's discovery, away from fixtures.

## Develop

```sh
tests/run.sh                                   # all tests, with `nvim`
NVIM_BIN=/path/to/nvim tests/run.sh tests/registry.lua
DOJO_TEST_SNACKS=/path/to/snacks.nvim tests/run.sh   # also open the real picker
```

`tests/solutions.lua` holds one solution, as typed keys, for every built-in
task: `lessons`, `drills` (scenario drills, one solution per scene) and `runs`
(drills that generate their rounds; the solution reads the round from the
buffer and types its answer). `manual` names the lessons a learner completes
by hand, each with the reason. `tests/native.lua` types each solution into
the running task: the untouched fixture must fail, every step before the last
must fail, a similar but wrong result must fail, the solution must pass, and
a reset must fail again. A new built-in task needs three things: the task in
its topic file, a line in one of the three level paths, and its solution. The
tests fail while one is missing.

Some solutions cannot be typed by one command that feeds all keys: a
command-line window does not open, and a prompt or a label that appears after
the first keys cannot be read. Name such a task in `interactive`.
`replay.remote()` starts a second editor (`nvim --headless --embed`) and
types those into it over RPC. That editor has a main loop, so it raises its
own events, and a solution function can wait (`replay.wait`) and read what is
on the screen before it types on.

A configuration can replay the same file under its own mappings and plugins,
to find built-in lessons that its setup changes:

```lua
local dir = "/path/to/neovim-dojo"
local replay = dofile(dir .. "/tests/replay.lua")
replay.all(dofile(dir .. "/tests/solutions.lua"))
local remote = replay.remote({ vim.v.progpath, "--headless", "--embed" }, dir .. "/tests/solutions.lua")
remote:all()
remote:close()
```

A driver that types into a real terminal can use the same solutions:
`replay.begin(solutions, id)` turns one into a coroutine, and `replay.next()`
returns what to do next: `{ keys = ... }` to type, `{ wait = ... }` to ask
again shortly, `{ step = n, of = m }` between the steps of a lesson, and
`{ done = true }`. Nothing in the editor is changed by these calls.

The tests start Neovim with `--clean` and a private state directory. They need
no other plugin: `tests/picker.lua` tests the picker against a recorder in
place of Snacks. `tests/picker_snacks.lua` opens the real Snacks picker and
types into it; it is skipped unless `DOJO_TEST_SNACKS` names a snacks.nvim
checkout. With `python3`, `tests/idle.py` also opens a task in a terminal and
checks that the editor stays idle.

### What an open task costs

While a task is open, the session listens to cursor, text, window and idle
events and checks the outcome after each. It is built to stay cheap:

- a burst of events shares one deferred check, and an idle tick (`SafeState`)
  checks at once without scheduling anything, so an open task does not keep the
  editor awake;
- whether a buffer belongs to a file-backed fixture is resolved on disk once
  per buffer name, not on every event.

`tests/events.lua` counts both. A hook of your own (`on_event`, a workspace
extension's `observe` or `check`, a custom checker) runs just as often, so keep
it to reading editor state.

## Credits

The round structure of the timed drills takes its idea from
[vim-be-good](https://github.com/ThePrimeagen/vim-be-good). The code is
original.

## Licence

MIT. See [LICENSE](LICENSE).
