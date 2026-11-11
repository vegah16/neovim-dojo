-- Curriculum conveniences; all returned tasks still use the public flat schema.
local M = {}
M.registers = { '"', "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "a", "b", "c" }
function M.lesson(id, title, objective, steps, lines, check, options)
  return vim.tbl_extend("force", {
    id = id,
    revision = 1,
    title = title,
    objective = objective,
    steps = steps,
    lines = lines,
    filetype = "text",
    check = vim.tbl_extend("force", { kind = "outcome" }, check),
    preserve_registers = M.registers,
  }, options or {})
end
function M.drill(id, title, objective, steps, scenes, options)
  return vim.tbl_extend("force", {
    id = id,
    revision = 1,
    kind = "drill",
    title = title,
    objective = objective,
    steps = vim.list_extend(
      { "Press `<CR>` to start. Each round is untimed; finish its goal, then press `,k` to check." },
      steps
    ),
    hint = "The round goal is in STATUS. `,k` checks the whole outcome, `,h` shows instructions, and `,r` abandons this attempt.",
    filetype = "text",
    preserve_registers = M.registers,
    drill = { kind = "scenarios", rounds = #scenes, scenes = scenes },
  }, options or {})
end
return M
