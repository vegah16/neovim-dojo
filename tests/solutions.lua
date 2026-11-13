-- One real solution for every automatically checked task of the built-in
-- pack; tests/replay.lua describes the format. Each task is listed under its
-- topic. `runs` holds the drills whose rounds are generated: their solution
-- reads the round and types its answer. `manual` names the lessons a learner
-- completes by hand, each with the reason.
local M = { lessons = {}, drills = {}, runs = {}, interactive = {}, manual = {} }
local L, D, R = M.lessons, M.drills, M.runs

-- The text of the open task's panel after `label`, up to the next separator.
local function shown(replay, label)
  return replay.panel():match(label .. " ([%w_]+)")
end
-- The first highlight of a generated round: its line and column, from 1 and 0.
local function target(namespace)
  local id = assert(vim.api.nvim_get_namespaces()[namespace], "no such namespace: " .. namespace)
  local mark = assert(vim.api.nvim_buf_get_extmarks(0, id, 0, -1, {})[1], "the round shows no target")
  return mark[2] + 1, mark[3]
end
local function count(number, key)
  return number == 0 and "" or (number == 1 and key or number .. key)
end

-- Navigation
R["hjkl-target-grid"] = function(replay)
  local row, column = target("neovim-dojo.drill-target")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local down, right = row - cursor[1], column - cursor[2]
  replay.keys(count(math.abs(down), down > 0 and "j" or "k") .. count(math.abs(right), right > 0 and "l" or "h"))
  replay.event("CursorMoved")
end
R["relative-line-delete"] = function(replay)
  local row = target("neovim-dojo.drill-text-target")
  local distance = row - vim.api.nvim_win_get_cursor(0)[1]
  replay.keys(count(math.abs(distance), distance > 0 and "j" or "k") .. "dd")
end
-- Every target is the first letter of a word; `w` reaches it from the start.
R["toggle-marked-character"] = function(replay)
  local _, column = target("neovim-dojo.drill-text-target")
  local _, words = vim.api.nvim_get_current_line():sub(1, column):gsub(" ", "")
  replay.keys("0" .. count(words, "w") .. "~")
end

-- Editing
R["delete-odd-word"] = function(replay)
  local _, column = target("neovim-dojo.drill-text-target")
  local _, words = vim.api.nvim_get_current_line():sub(1, column):gsub(" ", "")
  replay.keys(count(words, "w") .. "dw")
end
R["change-inside-container"] = function(replay)
  local brace = vim.api.nvim_get_current_line():find("{", 1, true)
  replay.keys((brace and "ci{" or "ci[") .. "dojo<Esc>")
end

-- Line and Screen Motions
L["line-start-end-motions"] = { "g_", wrong = { "$", "^" } }
L["goto-line-number"] = { "9G", wrong = "G" }
L["paragraph-motions"] = { "2}", wrong = "}" }
L["matching-pair-percent"] = { "%", wrong = "$" }
L["find-till-character"] = { "fs", "dtm", wrong = "fsdfm" }
L["enclosing-bracket-jumps"] = { "[{", wrong = "[(" }
L["position-line-in-window"] = { "40G", "zt", wrong = "40Gzb" }
D["line-motion-drill"] = { "g_", "7G", "%", "}", "^" }
D["find-till-drill"] = { "df:", "dt=", "ct]x<Esc>", "d2f/" }

-- Insert Mode
L["insert-entry-points"] = { "Ilocal <Esc>", "A;<Esc>", "olog value<Esc>" }
L["insert-with-count"] = "20i-<Esc>"
L["insert-delete-word-line"] = "Aredy<C-w>ready<Esc>"
L["insert-paste-register"] = { "yiW", "jA<C-r>0<Esc>" }
L["insert-indent-keys"] = { "jI<C-t><Esc>", "jI<C-d><C-d><Esc>" }
L["insert-special-character"] = "A<C-v>u00e9<Esc>"
L["replace-mode-overtype"] = "R2.0.0<Esc>"
D["insert-entry-drill"] = { "I- <Esc>", "A done<Esc>", "omiddle<Esc>", "Otitle<Esc>", "10i=<Esc>" }

-- Native Text Objects
L["inner-around-word"] = { "daw", wrong = "diw" }
L["quote-objects"] = 'ci"final<Esc>'
L["bracket-objects"] = { "di(", "f[da[" }
L["paragraph-object"] = { "dap", wrong = "dip" }
L["sentence-object"] = { "das", wrong = "dis" }
L["tag-object"] = { "citnew<Esc>", wrong = "dat" }
L["counted-objects"] = { "d2i(", wrong = "di(" }
D["text-object-drill"] = { "daw", "ci'ok<Esc>", "da[", "dap", "citx<Esc>" }
D["object-operator-drill"] = { "gUi(", "yi{$p", ">ip", "das" }

-- Precise Movement
L["word-versus-big-word"] = "3w"
L["counted-word-ends"] = "3e"
D["word-boundary-drill"] = { "3w", "3e", "2W" }
D["mark-edit-return-drill"] = { "maG$ciwnew<Esc>`a", "magg$ciwnew<Esc>`a", "maj0ciwnew<Esc>`a" }
L["backward-word-motions"] = { "2ge", wrong = "2b" }
L["jump-back-previous-position"] = {
  "G",
  "``",
  wrong = function(replay)
    replay.keys("G")
    replay.check()
    replay.keys("''")
  end,
}
L["revisit-older-change"] = { "$ciwnew<Esc>", "G$ciwnew<Esc>", "g;g;" }
L["line-and-exact-marks"] = {
  "ma",
  "G",
  "`a",
  wrong = function(replay)
    replay.keys("ma")
    replay.keys("G")
    replay.check()
    replay.keys("'a")
  end,
}
L["marks-as-ranges"] = { "jma", "jjd'a", wrong = "jmajjd`a" }
D["mark-range-drill"] = { "jmajjd'a", "majjgU'a", "jmaj>'a" }

-- Operators and Repeat
L["compose-operator-motion"] = "d2w"
L["operator-count-placement"] = "2d3w"
L["dot-repeat-separated-edits"] = { "ciwready<Esc>", "jj." }
L["join-and-reindent"] = { "J", "gg=G" }
D["operator-repair-drill"] = { "d2w", 'ci"ready<Esc>', "D" }
D["repeat-correction-drill"] = { "ciwready<Esc>jj.", "ciwdone<Esc>jj.", "ciwgo<Esc>jj." }
L["case-operators"] = { "gUiw", "jguu" }
L["indent-operators"] = { "j>j", "G<<." }
L["change-delete-to-line-end"] = { "Cdone<Esc>", "j0f#hD" }
L["swap-characters-lines"] = { "xp", "jddp" }
L["increment-numbers"] = { "<C-a>", "j5<C-x>", "j10<C-a>" }
L["increment-sequence"] = { "VGg<C-a>", wrong = "VG<C-a>" }
L["format-paragraph"] = "gqap"
L["replace-characters"] = { "4r*", wrong = "r*" }
D["case-indent-drill"] = { "gUiw", "guu", ">j", "g~~" }
D["number-adjust-drill"] = { "<C-a>", "20<C-x>", "VGg<C-a>", "<C-a>l<C-a>" }

-- Registers
L["retrieve-yank-register"] = { "yiw", "jdd", 'viw"0p', wrong = "yiwjddviwp" }
L["append-named-register"] = { '"ayy', 'j"Ayy', 'G"ap', wrong = '"ayyj"ayyG"ap' }
R["named-register-recall-drill"] = function(replay)
  local register = shown(replay, "save in register")
  replay.keys('"' .. register .. "yiw")
  replay.keys("jdd")
  replay.keys('$viw"' .. register .. "p")
end
L["put-before-after"] = { "Gdd", "ggP", wrong = "Gddggp" }
L["black-hole-delete"] = { "yy", 'j"_dd', "p", wrong = 'yyjdd"0p' }
L["numbered-delete-history"] = { "dddddd", '"3p', wrong = 'dddddd"1p' }
L["expression-register"] = "A<C-r>=24*60*60<CR><Esc>"
L["last-command-register"] = { ':echo "dojo"<CR>', '$":p' }
L["visual-put-keep-register"] = { "yiw", "jwviwP", "j0wviwP" }
L["yank-to-line-end"] = { "Y", "j$p" }
D["put-preserve-drill"] = { "GddggP", "yyp", "yiwjviwPjviwP", 'yyj"_ddkp' }

-- Visual and Block Editing
L["visual-selection-kinds"] = "Vd"
L["visual-ends-and-reselect"] = "viwooeU"
L["block-insert-column"] = "<C-v>jjI# <Esc>"
L["block-delete-rectangle"] = "<C-v>jjld"
D["column-patch-drill"] = { "<C-v>jjI# <Esc>", "<C-v>jjld", "<C-v>jjI> <Esc>" }
D["selection-boundary-drill"] = { "viweU", "viwU", "VU" }
L["block-append-ragged"] = { "<C-v>jj$A;<Esc>", wrong = "<C-v>jjA;<Esc>" }
L["block-change-column"] = "<C-v>jjecOK<Esc>"
L["visual-replace-underline"] = { "yyp", "Vr=" }
L["visual-indent-repeat"] = { "jVj>", "." }
D["block-append-change-drill"] = { "<C-v>jj$A,<Esc>", "<C-v>jjecDONE<Esc>", "Vr-" }

-- Native Search
L["literal-search-case"] = "/\\V\\CA.b<CR>"
L["whole-word-star-hash"] = "*"
L["search-direction-next"] = "?signal<CR>"
L["change-next-match"] = { "/\\<old\\><CR>cgnready<Esc>", "." }
D["search-occurrence-drill"] = { "/\\V\\CA.b<CR>", "*", "?signal<CR>" }
D["search-change-decoys-drill"] = {
  "/\\<old\\><CR>cgnready<Esc>.",
  "/\\<cat\\><CR>cgnfox<Esc>.",
  "/\\<run\\><CR>cgnwalk<Esc>.",
}
L["search-offset-end"] = { "/marker/e<CR>", wrong = "/marker<CR>" }
L["very-magic-alternation"] = { "/\\v(error|fatal)<CR>", "n", wrong = "/fatal<CR>" }
L["delete-to-search-match"] = "d/STOP<CR>"
L["visual-star-search"] = { "viW*", wrong = "/a.b<CR>" }
D["search-pattern-drill"] = { "/token/e<CR>", "/\\v(cat|dog)<CR>n", "d/END<CR>" }

-- Ranges and Ex
L["substitute-ranges"] = ":2,3s/old/new/g<CR>"
L["substitute-confirmation"] = ":%s/red/blue/gc<CR>yny"
L["substitute-captures"] = [[:1,2s/\v(\w+)[=](\d+)/\2: \1/<CR>]]
L["bounded-global-normal"] = ":1,4g/^TODO/normal! gUU<CR>"
D["capture-transform-drill"] = {
  [[:1,2s/\v(\w+)[=](\d+)/\2: \1/<CR>]],
  [[:1,2s/\v(\w+)[=](\d+)/\2: \1/<CR>]],
  [[:1,2s/\v(\w+)[=](\d+)/\2: \1/<CR>]],
}
D["filter-repair-drill"] = { ":1,3g/^TODO/normal! gUU<CR>", ":1,3g/^BAD/d<CR>", ":1,3v/^#/normal! A!<CR>" }
L["copy-move-lines-ex"] = { ":1t$<CR>", ":2m3<CR>" }
L["sort-unique-lines"] = { ":2,5sort u<CR>", wrong = { ":2,5sort<CR>", ":%sort u<CR>" } }
L["pattern-ranges"] = { ":/BEGIN/+1,/END/-1d<CR>", wrong = ":/BEGIN/,/END/d<CR>" }
L["mark-relative-ranges"] = { "j", ":.,+2d<CR>" }
L["normal-on-range"] = { ":1,3normal A;<CR>", wrong = ":%normal A;<CR>" }
L["substitute-case-modifiers"] = { [[:1,2s/\<\w/\u&/g<CR>]], wrong = [[:1,2s/\<\w/\u&/<CR>]] }
L["substitute-expression"] = { [[:1,2s/\d\+/\=submatch(0)*2/<CR>]], wrong = [[:%s/\d\+/\=submatch(0)*2/<CR>]] }
L["repeat-substitute"] = { ":s/old/new/g<CR>", "g&" }
L["collect-matching-lines"] = ":g/^TODO/t$<CR>"
L["read-write-ranges"] = { ":1r notes.txt<CR>", ":1,2w part.txt<CR>" }
L["substitute-last-search"] = { "*", ":1,2s//color/g<CR>" }
L["strip-trailing-retab"] = { [[:%s/\s\+$//<CR>]], ":retab<CR>" }
L["repeat-last-ex-command"] = { ":t.<CR>", "@:", "@@" }
D["ex-line-surgery-drill"] = {
  ":1t3<CR>",
  ":$m0<CR>",
  ":2,4sort<CR>",
  ":/BEGIN/+1,/END/-1d<CR>",
  ":1,3normal A,<CR>",
}
D["substitute-power-drill"] = {
  [[:1,2s/\<\w/\u&/g<CR>]],
  [[:1,2s/\d\+/\=submatch(0)*2/<CR>]],
  [[:%s/\s\+$//<CR>]],
  [[:1,2s/id: \zs\w\+/\U&/<CR>]],
}

-- Folds
L["toggle-fold-under-cursor"] = { "zc", wrong = "zM" }
L["close-open-all-folds"] = { "zM", "6Gzo", wrong = "zMzR" }
L["create-manual-fold"] = { "jzf2j", wrong = "jzfj" }
L["edit-closed-fold"] = { "jzc", "dd" }
D["fold-control-drill"] = { "jzc", "zM", "zR", "6Gzo" }

-- Windows
L["create-vertical-split"] = "<C-w>v"
L["balance-splits"] = "<C-w>="
L["navigate-native-splits"] = "<C-w>l"
L["close-other-windows"] = "<C-w>o"
L["move-window-to-tab"] = { "<C-w>T", "gT" }
L["tab-pages-navigate"] = { ":tabedit alpha.txt<CR>", "gT" }
L["open-file-under-cursor"] = { "gf", "<C-^>" }
L["resize-split-with-count"] = "10<C-w><"

-- Project Views
L["modified-buffer-safe-close"] = { "A retained<Esc>", ":close<CR>", wrong = ":close<CR>" }
L["two-views-one-file"] = { "<C-w>v", "A shared<Esc>" }
L["exchange-split-positions"] = { ":rightbelow vsplit alpha.txt<CR>", "<C-w>H" }
L["tab-local-directory"] = { ":tcd src<CR>", wrong = ":lcd src<CR>" }
D["reconstruct-layout-drill"] = { "<C-w>v", "<C-w>v<C-w>s", ":close<CR>" }
D["retrieve-working-set-drill"] = {
  { "AA<Esc>", ":tabedit alpha.txt<CR>", ":edit beta.txt<CR>", "gT" },
  { "AB<Esc>", ":tabedit beta.txt<CR>", ":edit src/keep.txt<CR>", "gT" },
}

-- Buffers
L["switch-hidden-buffer"] = ":buffer buffer-target<CR>"
L["switch-alternate-buffer"] = "<C-^>"
L["cycle-listed-buffers"] = ":bnext<CR>"
L["delete-hidden-buffer"] = ":bdelete buffer-scrap<CR>"
L["save-all-buffers"] = { "A saved<Esc>", ":edit alpha.txt<CR>A saved<Esc>", ":wall<CR>" }
L["discard-unsaved-changes"] = { "dd", ":edit!<CR>" }

-- Native Quickfix
L["vimgrep-quickfix"] = { ":vimgrep /TODO/ **/*.txt<CR>", ":cnext<CR>", wrong = ":edit beta.txt<CR>" }
L["quickfix-first-last"] = { ":clast<CR>", wrong = ":cnext<CR>" }
L["cdo-batch-change"] = { ":cdo s/TODO/DONE/ | update<CR>", wrong = ":cdo s/TODO/DONE/<CR>" }
L["location-list-local"] = { ":lvimgrep /TODO/ **/*.txt<CR>", ":lnext<CR>" }
D["quickfix-batch-drill"] = {
  ":cdo s/TODO/DONE/ | update<CR>",
  ":cdo s/$/ checked/ | update<CR>",
  ":cdo delete | update<CR>",
}

-- Command-line Editing. The command-line window does not open while one
-- command feeds the keys, so these three are typed into a second editor:
-- open the window, leave it with Ctrl-C for the pending command line, and
-- cancel that with Escape.
local function mode()
  return vim.api.nvim_get_mode().mode
end
local function command_window(open, kind)
  return function(replay)
    replay.keys(open)
    replay.wait("the command-line window", function()
      return vim.fn.getcmdwintype() == kind
    end)
    -- Ctrl-C is also the interrupt key, and an editor that is still busy
    -- opening the window takes it as that. Then it is pressed again.
    local function pending()
      return vim.fn.getcmdwintype() == "" and mode() == "c"
    end
    for _ = 1, 3 do
      replay.keys("<C-c>")
      local pressed = vim.uv.now()
      replay.wait("the pending command line", function()
        return pending() or vim.uv.now() - pressed > 1000
      end)
      if pending() then
        break
      end
    end
    assert(pending(), "Ctrl-C did not leave the command-line window")
    replay.keys("<Esc>")
    replay.wait("Normal mode", function()
      return mode() == "n"
    end)
  end
end
L["open-command-history"] = command_window("q:", ":")
L["edit-partial-command"] = function(replay)
  replay.keys(":echo 'Neovim Dojo'")
  replay.keys("<C-f>")
  replay.wait("the command-line window", function()
    return vim.fn.getcmdwintype() == ":"
  end)
  replay.keys("<CR>")
  replay.wait("Normal mode", function()
    return vim.fn.getcmdwintype() == "" and mode() == "n"
  end)
end
L["open-search-history"] = { command_window("q/", "/"), command_window("q?", "?") }
M.interactive["open-command-history"] = true
M.interactive["edit-partial-command"] = true
M.interactive["open-search-history"] = true
L["cmdline-word-under-cursor"] = ":1,2s/<C-r><C-w>/total/g<CR>"
L["cmdline-paste-register"] = { "yiW", "/<C-r>0<CR>", wrong = "/build<CR>" }
L["help-tag-jump"] = { ":help word-motions<CR>", "<C-w>p" }

-- Macros
L["record-replay-macro"] = { "qa0dWgUiwI- <Esc>j0q", "@a", "@@" }
L["count-inspect-macro"] = { "qa0dWgUiwI- <Esc>j0q", "5@a" }
R["macro-normalization-drill"] = function(replay)
  replay.keys("qa0dWgUiwI- <Esc>j0q")
  replay.keys("@a")
  replay.keys("@@")
  replay.keys("2@a")
  -- The drill waits for the editor to be idle after the last replay.
  replay.event("SafeState")
end
L["macro-on-range"] = { "qagUiwI- <Esc>q", ":2,4normal @a<CR>" }
L["append-to-macro"] = { "qaA!<Esc>q", "qAjq", "2@a" }

-- Undo History. Typing the final text makes no second branch and must fail.
L["recover-undo-branch"] = {
  "ciwalpha<Esc>",
  "u",
  "ciwbeta<Esc>",
  "g-",
  "yiw",
  "g+",
  "j$viwp",
  wrong = "ciwbeta<Esc>j$ciwalpha<Esc>",
}
R["undo-branch-recovery-drill"] = function(replay)
  local abandoned, chosen = shown(replay, "branch A:"), shown(replay, "branch B:")
  replay.keys("ciw" .. abandoned .. "<Esc>")
  replay.keys("u")
  replay.keys("ciw" .. chosen .. "<Esc>")
  replay.keys("g-")
  replay.keys("yiw")
  replay.keys("g+")
  replay.keys("j$viwp")
end
L["undo-time-travel"] = { "A one<Esc>", "A two<Esc>", "A three<Esc>", ":earlier 2<CR>" }

-- Comments and Blank Lines
L["toggle-comment-line"] = "gcc"
L["comment-motion-visual"] = { "gc2j", wrong = "gcj" }
L["comment-text-object"] = { "dgc", wrong = "dd" }
L["blank-lines-around"] = { "[<Space>", "]<Space>", wrong = "O<Esc>jo<Esc>" }
D["comment-toggle-drill"] = { "gcc", "gcj", "dgc", "gcG" }

-- Diff Mode
L["diff-two-files"] = { ":vertical diffsplit other.txt<CR>", wrong = ":vsplit other.txt<CR>" }
L["diff-obtain-put"] = { ":vertical diffsplit other.txt<CR>", "<C-w>p]cdo", "]cdp" }

-- Lessons that ask the learner to look and compare. Nothing they leave
-- behind tells a finished comparison from an unfinished one.
M.manual = {
  ["jump-list-change-list"] = "compares what the jump list and the change list remember",
  ["inspect-open-buffers"] = "reads the `:ls` listing and its flags",
  ["inspect-registers"] = "reads the `:registers` listing",
}
return M
