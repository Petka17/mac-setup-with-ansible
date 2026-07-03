-- File-type icons. Single-purpose (no plugin framework), auto-detected by
-- fzf-lua, oil, neogit, and diffview once installed — none of them need to be
-- told about it. Requires a nerd font (this config assumes one: see blink's
-- nerd_font_variant and the diagnostic signs in lua/lsp/init.lua).
--
-- No setup call is strictly required, but running one materialises the icon
-- highlight groups (linked to the active colorscheme) before the first picker
-- opens, so icons are coloured on the very first fzf-lua/oil window.
vim.pack.add({
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
})

require("nvim-web-devicons").setup({})
