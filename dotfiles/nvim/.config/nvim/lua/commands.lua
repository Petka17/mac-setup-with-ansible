-- Restore cursor to last known position when reopening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore cursor to last known position",
  group = vim.api.nvim_create_augroup("restore-cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("nightly-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.hl_op({ timeout = 500 })
  end,
})
