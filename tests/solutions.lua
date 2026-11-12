-- One real solution for every automatically checked task of the built-in
-- pack; tests/replay.lua describes the format. Each task is listed under its
-- topic. `elsewhere` names tasks that another test file covers, and `manual`
-- the lessons a learner completes by hand.
local M = { lessons = {}, drills = {}, manual = {}, elsewhere = {} }
local L, D = M.lessons, M.drills

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
L["close-other-windows"] = "<C-w>o"
L["move-window-to-tab"] = { "<C-w>T", "gT" }
L["tab-pages-navigate"] = { ":tabedit alpha.txt<CR>", "gT" }
L["open-file-under-cursor"] = { "gf", "<C-^>" }
L["resize-split-with-count"] = "10<C-w><"

-- Buffers
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

-- Command-line Editing
L["cmdline-word-under-cursor"] = ":1,2s/<C-r><C-w>/total/g<CR>"
L["cmdline-paste-register"] = { "yiW", "/<C-r>0<CR>", wrong = "/build<CR>" }
L["help-tag-jump"] = { ":help word-motions<CR>", "<C-w>p" }

-- Macros
L["macro-on-range"] = { "qagUiwI- <Esc>q", ":2,4normal @a<CR>" }
L["append-to-macro"] = { "qaA!<Esc>q", "qAjq", "2@a" }

-- Undo History
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

M.manual = { "jump-list-change-list", "inspect-open-buffers", "inspect-registers" }
-- Covered by lifecycle.lua, session.lua, registers.lua, macros.lua,
-- projects.lua and native.lua's own assertions.
M.elsewhere = {
  "hjkl-target-grid",
  "relative-line-delete",
  "toggle-marked-character",
  "delete-odd-word",
  "change-inside-container",
  "line-and-exact-marks",
  "recover-undo-branch",
  "undo-branch-recovery-drill",
  "switch-hidden-buffer",
  "switch-alternate-buffer",
  "retrieve-yank-register",
  "append-named-register",
  "named-register-recall-drill",
  "record-replay-macro",
  "count-inspect-macro",
  "macro-normalization-drill",
  "create-vertical-split",
  "balance-splits",
  "navigate-native-splits",
  "open-command-history",
  "edit-partial-command",
  "open-search-history",
  "modified-buffer-safe-close",
  "two-views-one-file",
  "exchange-split-positions",
  "tab-local-directory",
  "reconstruct-layout-drill",
  "retrieve-working-set-drill",
}
return M
