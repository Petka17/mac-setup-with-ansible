-- Theme
require("packages.catppuccin")

-- Icons (file-type glyphs; auto-detected by fzf-lua, oil, neogit, diffview).
-- After the theme so icon highlights link to the active colorscheme.
require("packages.devicons")

-- Navigation
require("packages.fzf")
require("packages.oil")

-- Git
require("packages.neogit")
require("packages.gitsigns")

-- Treesitter
require("packages.treesitter")

-- LSP foundation (must run before language stages)
require("packages.mason")
require("packages.luasnip")
require("packages.blink")

-- JSON schema catalog, consumed by lsp/jsonls.lua
require("packages.schemastore")

-- REST client
require("packages.kulala")

-- Database
require("packages.dbout")

-- Hledger
require("packages.ledger")
