-- Shared "import module specifier" toggle for the TypeScript servers: vtsls
-- (classic tsserver) and effect_tsgo (native TS7). Flips typescript/javascript
-- preferences.importModuleSpecifier between "shortest" and "non-relative" and
-- pushes it via workspace/didChangeConfiguration, so new auto-imports and
-- organize-imports react without restarting the LSP. Kept in one place so
-- lsp/vtsls.lua and lsp/effect_tsgo.lua stay aligned, mirroring lsp/js_project.lua.
local M = {}

-- The TS servers this toggle knows how to drive. They're mutually exclusive per
-- buffer (see is_effect_tsgo_project in js_project.lua), so at most one matches.
M.client_names = { "vtsls", "effect_tsgo" }

---@param bufnr integer
---@return vim.lsp.Client[]
local function ts_clients(bufnr)
  local out = {}
  for _, name in ipairs(M.client_names) do
    vim.list_extend(out, vim.lsp.get_clients({ bufnr = bufnr, name = name }))
  end
  return out
end

--- Toggle importModuleSpecifier between "shortest" and "non-relative" for every
--- TS client on the buffer. No restart required; the change affects new
--- auto-import suggestions and organize-imports immediately.
---@param bufnr integer
function M.toggle(bufnr)
  local clients = ts_clients(bufnr)
  if #clients == 0 then
    vim.notify("No TypeScript LSP client attached", vim.log.levels.WARN)
    return
  end

  -- Decide the style to switch *to* from the first client we see.
  local first = clients[1]
  local current = (((first.settings or {}).typescript or {}).preferences or {}).importModuleSpecifier
    or "non-relative"
  local next_style = (current == "shortest") and "non-relative" or "shortest"

  for _, c in ipairs(clients) do
    local cur_ts = c.settings.typescript or {}
    local cur_js = c.settings.javascript or {}

    local ts = vim.tbl_deep_extend("force", {}, cur_ts, {
      preferences = { importModuleSpecifier = next_style },
    })
    local js = vim.tbl_deep_extend("force", {}, cur_js, {
      preferences = { importModuleSpecifier = next_style },
    })

    c.settings.typescript = ts
    c.settings.javascript = js

    c:notify("workspace/didChangeConfiguration", {
      settings = { typescript = ts, javascript = js },
    })
  end

  vim.notify("TS import style → " .. next_style, vim.log.levels.INFO)
end

--- Report the current importModuleSpecifier for the buffer's TS client.
---@param bufnr integer
function M.show(bufnr)
  local clients = ts_clients(bufnr)
  if #clients == 0 then
    vim.notify("No TypeScript LSP client attached", vim.log.levels.WARN)
    return
  end
  local ts = (clients[1].settings or {}).typescript or {}
  local style = ((ts.preferences or {}).importModuleSpecifier or "non-relative")
  vim.notify("TS importModuleSpecifier: " .. style, vim.log.levels.INFO)
end

return M
