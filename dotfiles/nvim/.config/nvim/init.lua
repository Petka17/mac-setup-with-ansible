-- This config leans on Neovim 0.13 LSP/diagnostic APIs and experimental nightly
-- internals. Bail with a readable message instead of a stack trace on older builds.
if vim.fn.has("nvim-0.13") == 0 then
  vim.api.nvim_echo({
    {
      "This Neovim config requires 0.13+ (nightly). Current: " .. tostring(vim.version()),
      "ErrorMsg",
    },
  }, true, {})
  return
end

-- Experimental nightly UI; pcall so a renamed/removed internal degrades to a
-- warning instead of aborting startup before anything else loads.
local ok, err = pcall(function()
  require("vim._core.ui2").enable({})
end)
if not ok then
  vim.notify("vim._core.ui2 unavailable on this nightly: " .. tostring(err), vim.log.levels.WARN)
end

require("options")
require("commands")
require("keymaps")

-- Bail out of Treesitter/format/LSP on oversized buffers before they load.
require("custom.large-file")

-- Centered single-window layout, toggled with <leader>z.
require("custom.zen")

-- Packages first so blink.cmp capabilities exist when servers attach
require("pack")

-- LSP hub: diagnostic baseline, servers, format-on-save
require("lsp")
