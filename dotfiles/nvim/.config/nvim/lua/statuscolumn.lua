-- Custom 'statuscolumn' renderers, called from options.lua via
-- `v:lua.require'statuscolumn'.<fn>()`. Kept in a module (rather than globals)
-- so they don't trip selene's global_usage lint.
local M = {}

-- Arrow only on the line where a fold begins; blank everywhere else. This
-- replaces the built-in fold column, which falls back to printing the
-- nesting-level digit on lines inside nested folds.
function M.fold_column()
  local lnum = vim.v.lnum

  if vim.fn.foldlevel(lnum) <= vim.fn.foldlevel(lnum - 1) then
    return " " -- not a fold start
  end

  return vim.fn.foldclosed(lnum) == -1 and "▾" or "▸"
end

-- Absolute number on the cursor line, relative number elsewhere; skip the
-- virtual rows of wrapped lines. Fixed width keeps the column from jittering.
function M.number_column()
  if vim.v.virtnum ~= 0 then
    return ""
  end
  return string.format("%3d", vim.v.relnum == 0 and vim.v.lnum or vim.v.relnum)
end

return M
