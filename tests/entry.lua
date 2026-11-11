-- Runs the file named by DOJO_TEST_FILE and turns a failed assertion into a
-- nonzero exit status.
local test_file = assert(vim.env.DOJO_TEST_FILE, "DOJO_TEST_FILE must name the Lua test to run")
local ok, message = xpcall(function()
  dofile(test_file)
end, debug.traceback)
if not ok then
  io.stderr:write(message .. "\n")
  vim.cmd("cquit 1")
end
