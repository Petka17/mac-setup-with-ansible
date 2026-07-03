vim.g.mapleader = " "

-- Global Keymap

vim.keymap.set("n", "<leader>as", ":update<CR>:source<CR>")
vim.keymap.set("n", "<leader>W", ":wall<CR>")
vim.keymap.set("n", "<leader>w", ":write<CR>")
vim.keymap.set("n", "<leader>q", ":quit<CR>")
vim.keymap.set("n", "<leader>Q", ":bd<CR>")

vim.keymap.set("n", "<leader>aw", function()
  vim.o.wrap = not vim.o.wrap
end)

vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<C-c>", "<cmd>nohlsearch<CR>")

-- Keybinds to make split navigation easier.

vim.keymap.set("n", "<C-h>", "<C-w><C-h>")
vim.keymap.set("n", "<C-l>", "<C-w><C-l>")
vim.keymap.set("n", "<C-j>", "<C-w><C-j>")
vim.keymap.set("n", "<C-k>", "<C-w><C-k>")

-- Resize using alt+hjkl
local options = { noremap = true, silent = true }

vim.keymap.set("n", "<M-h>", ":vertical resize -2<CR>", options)
vim.keymap.set("n", "<M-j>", ":resize -2<CR>", options)
vim.keymap.set("n", "<M-k>", ":resize +2<CR>", options)
vim.keymap.set("n", "<M-l>", ":vertical resize +2<CR>", options)

-- Text manipulate
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", options)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", options)
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("n", "<leader>S", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], options)

-- Paste without overriding clipboard
vim.keymap.set("x", "<leader>p", '"_dP', options)

-- Quick fix
vim.keymap.set("n", "]x", ":cnext<CR>", options)
vim.keymap.set("n", "[x", ":cprev<CR>", options)
vim.keymap.set("n", "<leader>xf", ":cclose<CR>", options)

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)

-- Open the diagnostic float after landing on a diagnostic. The old `float = true`
-- jump option is deprecated in favor of the on_jump callback.
local function on_jump(diagnostic, bufnr)
  if diagnostic then
    vim.diagnostic.open_float({ bufnr = bufnr })
  end
end
local function diag_prev()
  vim.diagnostic.jump({ count = -1, on_jump = on_jump })
end
local function diag_next()
  vim.diagnostic.jump({ count = 1, on_jump = on_jump })
end

-- Global maps cover buffers without a filetype. But several built-in ftplugins
-- (python, markdown, c, …) install buffer-local [[ / ]] section-motion maps, and
-- buffer-local maps shadow global ones — which is why diagnostic jumps silently
-- did nothing in Python/Markdown while working in TS/YAML. Re-assert our maps
-- buffer-local on every FileType (scheduled so we run after the ftplugin's own
-- FileType handler) so [[ / ]] navigate diagnostics everywhere.
vim.keymap.set("n", "[[", diag_prev)
vim.keymap.set("n", "]]", diag_next)
vim.api.nvim_create_autocmd("FileType", {
  desc = "Reclaim [[ / ]] for diagnostic navigation over ftplugin section motions",
  group = vim.api.nvim_create_augroup("diagnostic-nav", { clear = true }),
  callback = function(ev)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      vim.keymap.set("n", "[[", diag_prev, { buffer = ev.buf })
      vim.keymap.set("n", "]]", diag_next, { buffer = ev.buf })
    end)
  end,
})

vim.keymap.set("n", "<leader>xl", vim.diagnostic.setqflist)
