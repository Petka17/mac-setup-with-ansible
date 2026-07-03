-- Remote-plugin providers
-- Disable the perl/ruby/node/python3 host providers. None of the plugins here
-- are remote plugins (LSP/formatters run as their own processes; kulala/dbout
-- shell out via vim.system, not the node provider), so these only ever surface
-- as :checkhealth warnings. Turning them off keeps the health report clean and
-- skips the provider probes at startup.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- OS integration
-- Use system clipboard for yank/paste operations
vim.opt.clipboard = "unnamedplus"
-- Enable mouse support in normal and visual modes
vim.opt.mouse = "nv"

-- File Management
-- Disable creation of backup files to avoid clutter
vim.opt.backup = false
-- Disable creation of swap files to avoid clutter
vim.opt.swapfile = false
-- Enable persistent undo across sessions
vim.opt.undofile = true
-- Directory to store undo files
vim.opt.undodir = os.getenv("HOME") .. "/.cache/nvim/undodir"
-- Don't automatically change working directory to current file's directory
vim.opt.autochdir = false
-- Prompt for confirmation when quitting with unsaved changes
vim.opt.confirm = true
-- Detect changes outside the NeoVim and refresh the file content
vim.opt.autoread = true

-- UI and Visual
-- Display absolute line numbers in the gutter
vim.opt.number = true
-- Display relative line numbers for easier navigation
vim.opt.relativenumber = true
-- Highlight the line where the cursor is located
vim.opt.cursorline = true
-- Don't highlight the column where the cursor is located
vim.opt.cursorcolumn = false
-- Always show two sign columns so git hunk signs (gitsigns) and diagnostic
-- signs render side by side instead of fighting for one cell.
vim.opt.signcolumn = "yes:2"
-- Don't display current mode (INSERT, NORMAL, etc.) in the command line
vim.opt.showmode = false
-- Set command line height to 0 line
vim.opt.cmdheight = 0
-- Use rounded borders for floating windows
vim.opt.winborder = "rounded"
-- Fire CursorHold ~250ms after the cursor stops (default 4000ms is tuned for the
-- legacy swap-file flush, not interactive UI). LSP document-highlight and hold-driven
-- CodeLens (see lua/lsp/init.lua) hang off CursorHold, so the long default starves
-- them; swap is disabled above, so the original reason for a high value doesn't apply.
vim.opt.updatetime = 250
-- Show invisible characters like tabs and trailing spaces
vim.opt.list = true
-- Customize how invisible characters are displayed
vim.opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}
-- Buffer status line
vim.opt.statusline =
  '%f %m %= %l/%L %{getfsize(expand("%")) < 0 ? "N/A" : printf("%.1fK", getfsize(expand("%")) / 1024.0)}'

-- Window and Scrolling
-- Keep 5 lines visible above and below the cursor when scrolling
vim.opt.scrolloff = 5
-- Keep 5 columns visible to the left and right of the cursor when scrolling
vim.opt.sidescrolloff = 5
-- Open new vertical splits to the right of the current window
vim.opt.splitright = true
-- Open new horizontal splits below the current window
vim.opt.splitbelow = true

-- Indentation
-- Set tab width to 2 spaces
vim.opt.tabstop = 2
-- Set indentation width to 2 spaces
vim.opt.shiftwidth = 2
-- Use spaces instead of tab characters for indentation
vim.opt.expandtab = true
-- Note: no `smartindent` — Treesitter sets `indentexpr` per-buffer
-- (see lua/packages/treesitter.lua), and smartindent fights it (e.g. yanking
-- `#`-led lines to column 0) in buffers without a Treesitter indent.

-- Text Wrapping
-- Wrap lines that exceed the window width
vim.opt.wrap = true
-- Break wrapped lines at word boundaries instead of mid-word
vim.opt.linebreak = true
-- Maintain indentation when wrapping lines
vim.opt.breakindent = true

-- Search
-- Highlight matches as you type in search
vim.opt.incsearch = true
-- Case-sensitive search only if search contains uppercase letters
vim.opt.smartcase = true
-- Ignore case in search patterns
vim.opt.ignorecase = true
-- Show preview of substitute command results in buffer
vim.opt.inccommand = "nosplit"
-- Include dash (-) as part of keywords for word operations
vim.opt.iskeyword:append("-")

vim.opt.isfname:append("@-@")

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldtext = ""
vim.opt.fillchars = {
  fold = " ", -- filler inside folds (space = no dashes)
}

-- Render the fold column ourselves via 'statuscolumn'. The built-in fold
-- column draws an arrow on a fold's first line but falls back to printing the
-- nesting-level *digit* on lines inside nested folds (because a 1-wide column
-- can't fit a marker for each level). We want the arrows but not the digits,
-- so we draw the column by hand and let 'foldcolumn' itself stay off.
vim.opt.foldcolumn = "0"

-- Renderers live in lua/statuscolumn.lua and are called via `v:lua.require`
-- (rather than globals) so they don't trip selene's global_usage lint.
vim.opt.statuscolumn = table.concat({
  "%#FoldColumn#%{v:lua.require'statuscolumn'.fold_column()}%*", -- fold arrows (no nesting digits)
  "%s", -- sign column
  "%{v:lua.require'statuscolumn'.number_column()} ", -- line numbers + gap before text
})

-- Text editing
-- Configure automatic text formatting options. Must be `vim.opt`/`vim.o`, not
-- `vim.g`: formatoptions is a buffer option, so `vim.g.formatoptions` only sets
-- an unused global variable and leaves the actual option at its default.
vim.opt.formatoptions = "tcqj"
