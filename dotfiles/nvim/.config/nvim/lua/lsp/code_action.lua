-- Shared synchronous `source.*` code-action applier.
--
-- Used by the format-on-save paths: the JS/TS pipeline (lsp/ts_format.lua) runs
-- source.fixAll.eslint / source.fixAll.oxc through here, and the generic
-- resolver (lsp/format.lua) runs ruff's source.organizeImports before its format
-- pass. Everything runs synchronously inside BufWritePre, before the write.

local M = {}

---Apply a `source.*` code action synchronously to a buffer. Resolves actions
---that arrive without an edit (LSP servers may defer the edit until
---codeAction/resolve) and executes any attached command.
---@param bufnr integer
---@param client vim.lsp.Client the attached client to request the action from
---@param kind string code-action kind, e.g. "source.organizeImports.ruff"
---@param diagnostics? table[] LSP diagnostics for the request context. Some
---  servers (eslint/oxlint) build their fixAll edit from these; pass nil/{} when
---  the action does not depend on diagnostics (e.g. organize-imports).
function M.apply(bufnr, client, kind, diagnostics)
  local enc = client.offset_encoding or "utf-16"
  local params = vim.lsp.util.make_range_params(0, enc)
  params.range = {
    start = { line = 0, character = 0 },
    ["end"] = { line = vim.api.nvim_buf_line_count(bufnr), character = 0 },
  }
  params.context = { only = { kind }, diagnostics = diagnostics or {} }

  local resp = client:request_sync("textDocument/codeAction", params, 3000, bufnr)
  if not (resp and resp.result) then
    return
  end

  for _, action in ipairs(resp.result) do
    local resolved = action
    -- Actions may arrive without an edit; resolve to materialise it.
    if not action.edit and client:supports_method("codeAction/resolve") then
      local rr = client:request_sync("codeAction/resolve", action, 3000, bufnr)
      if rr and rr.result then
        resolved = rr.result
      end
    end

    if resolved.edit then
      vim.lsp.util.apply_workspace_edit(resolved.edit, enc)
    end
    if resolved.command then
      local command = type(resolved.command) == "table" and resolved.command or resolved
      client:request_sync("workspace/executeCommand", {
        command = command.command,
        arguments = command.arguments,
      }, 3000, bufnr)
    end
  end
end

return M
