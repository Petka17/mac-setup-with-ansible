local M = {}

-- Priority list resolved at format time. Higher index = higher priority.
local registry = {}

---Register or update the priority of a formatter client. Idempotent:
---calling register("efm", 90) then register("efm", 95) leaves a single
---entry at priority 95.
---@param name string Client name (e.g. "biome", "stylua", "ruff")
---@param priority integer Higher wins; same-priority falls back to first attached
function M.register(name, priority)
  for _, entry in ipairs(registry) do
    if entry.name == name then
      entry.priority = priority
      table.sort(registry, function(a, b)
        return a.priority > b.priority
      end)
      return
    end
  end
  table.insert(registry, { name = name, priority = priority })
  table.sort(registry, function(a, b)
    return a.priority > b.priority
  end)
end

---@return string[] ordered client names, most-preferred first
function M.priority_order()
  local names = {}
  for _, entry in ipairs(registry) do
    table.insert(names, entry.name)
  end
  return names
end

---Run formatting on a buffer, picking the highest-priority *registered* client
---that supports textDocument/formatting. Only registered formatters run — an
---unregistered client is never allowed to reformat the buffer by surprise.
---@param bufnr integer
function M.format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- JS/TS runs its own ordered "run every available tool" pipeline instead of
  -- the single-winner resolver below.
  local ts_fts = {
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
  }
  if ts_fts[vim.bo[bufnr].filetype] then
    require("lsp.ts_format").run(bufnr)
    return
  end

  -- Python: `ruff format` deliberately does NOT sort imports — that's ruff's
  -- source.organizeImports code action. Run it first so imports are sorted, then
  -- fall through to the single-winner resolver below, which runs `ruff format`
  -- to normalise spacing around the freshly-sorted imports.
  if vim.bo[bufnr].filetype == "python" then
    local ruff = vim.lsp.get_clients({ bufnr = bufnr, name = "ruff" })[1]
    if ruff then
      require("lsp.code_action").apply(bufnr, ruff, "source.organizeImports.ruff")
    end
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    return
  end

  local by_name = {}
  for _, c in ipairs(clients) do
    by_name[c.name] = c
  end

  for _, entry in ipairs(registry) do
    local client = by_name[entry.name]
    if client and client:supports_method("textDocument/formatting") then
      vim.lsp.buf.format({
        bufnr = bufnr,
        timeout_ms = 5000,
        filter = function(c)
          return c.name == entry.name
        end,
      })
      return
    end
  end
end

return M
