-- Center the current layout by padding it with two empty side windows —
-- the same trick zen-mode plugins use, without the dependency. Toggle with
-- <leader>z. The pads are unlisted scratch buffers in unfocusable windows,
-- so window navigation (<C-h>/<C-l>) and :bnext never land in them.

local M = {}

M.width = 120 -- target width of the centered text area

local pads = {}

local function close_pads()
  for _, win in ipairs(pads) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  pads = {}
end

function M.toggle()
  if #pads > 0 then
    close_pads()
    return
  end
  local pad_width = math.floor((vim.o.columns - M.width) / 2)
  if pad_width < 1 then
    return -- screen too narrow, nothing to center
  end
  for _, side in ipairs({ "left", "right" }) do
    local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
    vim.bo[buf].bufhidden = "wipe"
    local win = vim.api.nvim_open_win(buf, false, {
      split = side,
      win = -1, -- top-level split: full height, outermost column
      width = pad_width,
      focusable = false,
    })
    vim.wo[win].winfixwidth = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].statuscolumn = ""
    vim.wo[win].statusline = " "
    vim.wo[win].fillchars = "eob: " -- hide the ~ end-of-buffer marks
    table.insert(pads, win)
  end
end

-- Close pads before :q so quitting the real window exits Neovim normally.
vim.api.nvim_create_autocmd("QuitPre", {
  desc = "Close zen pad windows so :q exits normally",
  group = vim.api.nvim_create_augroup("zen-pads", { clear = true }),
  callback = close_pads,
})

vim.keymap.set("n", "<leader>z", M.toggle, { desc = "Toggle centered (zen) layout" })

return M
