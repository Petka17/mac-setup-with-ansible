-- Close the quickfix or location list with a single `q` press (like :help, netrw, etc.).
vim.keymap.set("n", "q", function()
  local winid = vim.api.nvim_get_current_win()
  local info = vim.fn.getwininfo(winid)[1]
  if info and info.loclist == 1 then
    vim.cmd("lclose")
  else
    vim.cmd("cclose")
  end
end, { buffer = true, silent = true, nowait = true, desc = "Close quickfix or location list" })
