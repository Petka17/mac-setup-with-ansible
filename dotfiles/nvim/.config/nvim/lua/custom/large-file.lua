-- Flags oversized buffers as `vim.b.large_buf` so the expensive per-buffer
-- machinery can short-circuit: Treesitter highlight/indent (parses the whole
-- file), format-on-save (blocks the write up to timeout_ms), and LSP (vtsls
-- indexing a minified bundle). The decision is made on BufReadPre, which fires
-- before Treesitter's FileType handler and before any LSP matcher, so the flag
-- is set in time for both.

local M = {}

-- Files at or above this byte size are treated as "large".
M.threshold = 1.5 * 1024 * 1024 -- 1.5 MB

local group = vim.api.nvim_create_augroup("nightly-large-file", { clear = true })

vim.api.nvim_create_autocmd("BufReadPre", {
  group = group,
  desc = "Flag oversized buffers as large",
  callback = function(args)
    local name = vim.api.nvim_buf_get_name(args.buf)
    local ok, stats = pcall(vim.uv.fs_stat, name)
    vim.b[args.buf].large_buf = (ok and stats ~= nil and stats.size >= M.threshold) or false
  end,
})

-- No pre-attach hook exists for vim.lsp.enable's matchers, so we detach right
-- after attach instead. Scheduled so the detach runs outside the attach
-- callback. pcall-guarded because the detach API churns on nightly.
vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  desc = "Detach LSP from large buffers",
  callback = function(args)
    if not vim.b[args.buf].large_buf then
      return
    end
    vim.schedule(function()
      pcall(vim.lsp.buf_detach_client, args.buf, args.data.client_id)
    end)
  end,
})

return M
