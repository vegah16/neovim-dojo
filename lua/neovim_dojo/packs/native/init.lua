-- The built-in curriculum: native Vim and Neovim only. It needs no plugin and
-- no particular mapping, so every task works in a stock configuration.
return {
  id = "native",
  title = "Native Neovim",
  topics = {
    require("neovim_dojo.packs.native.topics.navigation"),
    require("neovim_dojo.packs.native.topics.precision"),
    require("neovim_dojo.packs.native.topics.operators"),
    require("neovim_dojo.packs.native.topics.visual"),
    require("neovim_dojo.packs.native.topics.search"),
    require("neovim_dojo.packs.native.topics.ex"),
    require("neovim_dojo.packs.native.topics.editing"),
    require("neovim_dojo.packs.native.topics.undo_history"),
    require("neovim_dojo.packs.native.topics.buffers"),
    require("neovim_dojo.packs.native.topics.registers"),
    require("neovim_dojo.packs.native.topics.macros"),
    require("neovim_dojo.packs.native.topics.windows"),
    require("neovim_dojo.packs.native.topics.command_line"),
    require("neovim_dojo.packs.native.topics.project_views"),
  },
  paths = { require("neovim_dojo.packs.native.paths.fundamentals") },
}
