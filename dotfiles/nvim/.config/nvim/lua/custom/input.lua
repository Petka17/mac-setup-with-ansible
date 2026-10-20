-- Replace the cmdline prompt behind vim.ui.input (LSP rename via `grn`, etc.)
-- with a small floating buffer, so the answer is edited with full Vim motions.
-- It stands in for the cmdwin: since the Lua cmdwin rewrite (neovim#40312) the
-- 'cedit' key no longer opens it from input() prompts (neovim#40407). Like the
-- cmdwin it lists the input() history above the current value, and <CR> on any
-- line confirms that line.
--   <CR>      confirm (insert or normal mode)
--   <Esc>, q  cancel (normal mode)
--   <C-c>     cancel (either mode)
-- `opts.completion` and `opts.highlight` are ignored.

local M = {}

M.min_width = 40 -- narrowest the float gets, in columns

function M.input(opts, on_confirm)
  opts = opts or {}

  -- Oldest first, like the cmdwin; histget() yields "" for removed entries.
  local lines = {}
  for i = 1, vim.fn.histnr("input") do
    local entry = vim.fn.histget("input", i)
    if entry ~= "" then
      table.insert(lines, entry)
    end
  end
  table.insert(lines, opts.default or "")

  local title = (vim.trim(opts.prompt or "Input"):gsub(":$", ""))
  local width = math.max(M.min_width, #title + 2)
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 1)
  end
  local height = math.min(#lines, vim.o.cmdwinheight)

  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Open below the cursor, or above it when the float would not fit.
  local fits_below = vim.o.lines - vim.o.cmdheight - vim.fn.screenrow() >= height + 3
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    anchor = fits_below and "NW" or "SW",
    row = fits_below and 1 or 0,
    col = 0,
    width = math.min(width, vim.o.columns - 4),
    height = height,
    style = "minimal",
    title = " " .. title .. " ", -- needs a border; 'winborder' provides it
  })
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  vim.cmd.startinsert({ bang = true }) -- append to the current value

  local done = false
  local function finish(value)
    if done then
      return
    end
    done = true
    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if value and value ~= "" then
      vim.fn.histadd("input", value)
    end
    -- Scheduled so the caller runs back in its own window, out of insert mode.
    vim.schedule(function()
      on_confirm(value)
    end)
  end
  local function confirm()
    finish(vim.api.nvim_get_current_line())
  end
  local function cancel()
    finish(nil)
  end

  -- Leave insert mode inside the float before running `fn`; closing it
  -- mid-insert would carry insert mode over to the caller's window. A callback
  -- rather than an "<Esc><CR>" rhs, which blink.cmp's <CR> fallback would
  -- replay without remapping.
  local function after_insert(fn)
    return function()
      vim.api.nvim_create_autocmd("ModeChanged", { pattern = "i:n", once = true, callback = fn })
      vim.cmd.stopinsert()
    end
  end

  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, nowait = true })
  end
  map("n", "<CR>", confirm)
  map("n", "<C-c>", cancel)
  map("n", "<Esc>", cancel)
  map("n", "q", cancel)
  map("i", "<CR>", after_insert(confirm))
  map("i", "<C-c>", after_insert(cancel))

  -- :q, <C-w>c and friends count as cancelling.
  vim.api.nvim_create_autocmd("WinClosed", {
    desc = "Cancel the input float when its window is closed",
    pattern = tostring(win),
    once = true,
    callback = cancel,
  })
end

vim.ui.input = M.input

return M
