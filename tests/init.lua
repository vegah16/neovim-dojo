-- Minimal init for the test suite: this plugin and nothing else.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Some relocatable builds keep the bundled parsers under lib64/nvim.
local lib64 = vim.fs.normalize(vim.env.VIMRUNTIME .. "/../../../lib64/nvim")
if (vim.uv or vim.loop).fs_stat(lib64) then
  vim.opt.runtimepath:append(lib64)
end
