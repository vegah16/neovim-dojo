local a = require("neovim_dojo.author")
local preserved = { "a", "b", "c", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-" }

return {
  id = "registers",
  title = "Registers",
  description = "Inspect, preserve, and retrieve text independently of the last edit.",
  topics = { "editing" },
  source = { kind = "vim" },
  keywords = { "register", ":reg", ":registers", "unnamed", "yank", "black hole", "clipboard" },
  lessons = {
    {
      id = "inspect-registers",
      title = "Inspect the registers",
      objective = "Distinguish the unnamed, yank, named, black-hole, and clipboard registers.",
      steps = {
        'Yank `amber` with `yiw`, then inspect `:reg` or `:registers`. `"` is the unnamed register and `0` holds the latest yank.',
        'Inspect a smaller set with `:reg " 0 a`. Ordinary deletes can replace the unnamed register while `0` keeps the yank.',
        'Named registers such as `a` keep text until overwritten; uppercase `A` appends to `a`. `"_dd` deletes into the black-hole register without replacing saved text.',
        'Clipboard registers `+` and `*` depend on the host and its clipboard provider; `"+y` yanks to the system clipboard. Clipboard access is not required here.',
        "Press `,m` after you can identify the roles in the register list.",
      },
      hint = "The register prefix is a double quote followed by its name. `:reg a` displays text or macro keystrokes in register a.",
      filetype = "text",
      lines = { "amber", "spare text for an unrelated delete" },
      cursor = { 1, 0 },
      check = { kind = "manual" },
      preserve_registers = preserved,
    },
    {
      id = "retrieve-yank-register",
      title = "Retrieve the yank after a delete",
      objective = "Keep `amber` through a line deletion and replace `none` using register `0`.",
      bindings = { origin = "native" },
      steps = {
        "Yank `amber` with `yiw`, then use `jdd` to delete the unrelated `discard` line.",
        'The unnamed register now holds the deletion. Inspect `:reg " 0` to see why plain `p` would paste the wrong text.',
        'On `none`, use `viw"0p` to paste explicitly from the yank register. The result should be two lines containing `amber`.',
      },
      hint = "`0` is the latest yank, not the latest delete. The explicit register prefix selects it even after another edit.",
      filetype = "text",
      lines = { "amber", "discard", "none" },
      cursor = { 1, 0 },
      check = { kind = "buffer_equals", lines = { "amber", "amber" } },
      preserve_registers = preserved,
    },
    {
      id = "append-named-register",
      title = "Append to a named register",
      objective = "Collect two lines in `a`, then paste the collection beneath `paste below`.",
      bindings = { origin = "native" },
      steps = {
        'Yank the first line with `"ayy`. Move down with `j` and use `"Ayy` to append the second line to the same register.',
        "Run `:reg a` to inspect the two-line collection. Lowercase overwrites; uppercase appends.",
        'Move to the last line with `G` and use `"ap` to paste both collected lines below it.',
      },
      hint = "Linewise yanks retain line boundaries. This lesson restores the previous contents of `a` when it closes.",
      filetype = "text",
      lines = { "amber", "gold", "paste below" },
      cursor = { 1, 0 },
      check = { kind = "buffer_equals", lines = { "amber", "gold", "paste below", "amber", "gold" } },
      preserve_registers = preserved,
    },
    {
      id = "named-register-recall-drill",
      kind = "drill",
      title = "Preserve and recall named registers",
      objective = "Save a token in the requested register, delete unrelated text, and recall it in three varied rounds.",
      bindings = { origin = "native" },
      keywords = { "a", "b", "c", "recall", "timed", "personal best" },
      steps = {
        "Press `<CR>` and read the requested register in `STATUS`.",
        'On the highlighted token, use `"ayiw`, replacing `a` with the requested register.',
        'Use `jdd` to delete `discard = spare`. On `none`, use `$viw"ap`, again selecting the requested register.',
        "Each round requires the named yank, the unrelated deletion, and the correct final text. Complete three rounds to record a time.",
      },
      hint = "The named register survives ordinary deletes. Use `:reg a` (or b/c) if you need to inspect it; the timer continues.",
      filetype = "text",
      preserve_registers = preserved,
      drill = {
        kind = "text_actions",
        variant = "register_recall",
        rounds = 3,
        registers = { "a", "b", "c" },
        words = {
          "amber",
          "birch",
          "coral",
          "daisy",
          "ember",
          "flint",
          "grove",
          "hazel",
          "ivory",
          "maple",
          "raven",
          "stone",
        },
      },
    },
    a.lesson(
      "put-before-after",
      "Put before or after",
      "Move the line `one` from the bottom to the top.",
      {
        "`p` puts after the cursor and `P` before it. For whole lines that means below and above the current line.",
        "Go to the last line with `G` and cut it with `dd`.",
        "Go to the first line with `gg` and press `P`. A lower-case `p` would put it under `two`.",
      },
      { "two", "three", "one" },
      { lines = { "one", "two", "three" } },
      { keywords = { "p", "P", "put", "paste", "linewise" } }
    ),
    a.lesson(
      "black-hole-delete",
      "Delete without losing a yank",
      "Yank the line `wanted`, delete `junk` without replacing the yank, and put `wanted` below `slot:`.",
      {
        "Yank the first line with `yy`.",
        'On `junk` type `"_dd`: the black-hole register `"_` takes the text and keeps nothing.',
        "The unnamed register still holds `wanted`. Press `p` on `slot:`.",
        'A plain `dd` would overwrite the unnamed register; the yank would then only be left in `"0`.',
      },
      { "wanted", "junk", "slot:" },
      { lines = { "wanted", "slot:", "wanted" }, register = { name = '"', value = "wanted\n" } },
      { keywords = { '"_', '"_dd', "black hole", "unnamed" } }
    ),
    a.lesson(
      "numbered-delete-history",
      "Get back an earlier delete",
      "Delete the first three lines one at a time, then put back only `first`, below `keep`.",
      {
        "Press `dd` three times. Every deleted line goes into register `1`, and the older ones shift to `2`, `3` and so on, up to `9`.",
        'Inspect them with `:reg 1 2 3`. `first` was deleted first, so it is now in register `3`: type `"3p`.',
        'To walk through them without counting, use `"1p` and then `u.`: each repeat puts the next older delete.',
      },
      { "first", "second", "third", "keep" },
      { lines = { "keep", "first" } },
      { keywords = { '"1', '"3p', "numbered", "delete history", "u." } }
    ),
    a.lesson(
      "expression-register",
      "Insert the result of an expression",
      "Complete the line with the number of seconds in a day, calculated by Neovim.",
      {
        "Press `A` to append, then `<C-r>=`. The command line shows `=` and waits for an expression.",
        "Type `24*60*60` and press `<CR>`. The result is inserted as if typed. Press `<Esc>`.",
        "Any expression works, such as `<C-r>=strftime('%Y')<CR>`.",
      },
      { "seconds per day = ", "protected" },
      { lines = { "seconds per day = 86400", "protected" } },
      { keywords = { "C-r =", '"=', "expression", "calculate" } }
    ),
    a.lesson(
      "last-command-register",
      "Put the last command into the text",
      'Run `:echo "dojo"`, then put that command at the end of the line.',
      {
        'Type `:echo "dojo"` and press `<CR>`.',
        'Register `:` holds the last command line. Go to the end of the line with `$` and type `":p`.',
        'More read-only registers: `".` is the last inserted text, `"%` the file name and `"/` the last search pattern.',
      },
      { "last command: ", "protected" },
      { lines = { 'last command: echo "dojo"', "protected" } },
      { keywords = { '":', '".', '"%', '"/', "read-only register" } }
    ),
    a.lesson(
      "visual-put-keep-register",
      "Replace several selections with one yank",
      "Replace `bad` on both lines with the yanked word `good`.",
      {
        "Yank `good` with `yiw`.",
        "On the first `bad` type `viwP`. In Visual mode an upper-case `P` replaces the selection and leaves the registers alone.",
        "Do the same on the second `bad`. A lower-case `p` would have put the replaced `bad` into the unnamed register.",
      },
      { "good", "one bad", "two bad" },
      { lines = { "good", "one good", "two good" }, register = { name = '"', value = "good" } },
      { keywords = { "viwP", "P", "visual", "replace", "put" } }
    ),
    a.lesson(
      "yank-to-line-end",
      "Yank to the end of the line",
      "Yank from `first` to the end of its line and put it at the end of the second line.",
      {
        "The cursor is on `first`. Press `Y`: in Neovim it yanks to the end of the line, like `y$`. `yy` yanks the whole line.",
        "On the second line press `$` and then `p`.",
      },
      { "keep = first; second", "paste here: " },
      { lines = { "keep = first; second", "paste here: first; second" } },
      { source = { kind = "neovim" }, cursor = { 1, 7 }, keywords = { "Y", "y$", "yy", "yank" } }
    ),
    a.drill("put-preserve-drill", "Yank, put and preserve", "Move and copy text with deliberate puts.", {
      'Use `p`, `P`, a Visual `P` and the black-hole register `"_`.',
    }, {
      {
        goal = "Move the last line to the top",
        lines = { "b", "c", "a" },
        check = { lines = { "a", "b", "c" } },
      },
      {
        goal = "Duplicate the first line",
        lines = { "only", "protected" },
        check = { lines = { "only", "only", "protected" } },
      },
      {
        goal = "Replace both x with the word good",
        lines = { "good", "x", "x" },
        check = { lines = { "good", "good", "good" } },
      },
      {
        goal = "Replace the line junk with a copy of the line keep",
        lines = { "keep", "junk", "protected" },
        check = { lines = { "keep", "keep", "protected" } },
      },
    }),
  },
}
