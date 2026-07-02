-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("nightly-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.hl_op({ timeout = 500 })
  end,
})
