-- ruff: Python linter + formatter + import organizer, via `ruff server`.
--
-- ruff is Python's sole formatter (registered in the format resolver at
-- priority 100 in lua/lsp/init.lua). Import sorting runs automatically on save
-- via ruff's source.organizeImports code action (see lua/lsp/format.lua), so
-- there is no manual organize-imports command. basedpyright provides hover/type
-- info, so ruff's own hover is suppressed on attach to avoid a duplicate popup.
---@type vim.lsp.Config
return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "ruff.toml",
    ".ruff.toml",
    ".git",
  },
  settings = {},
  on_attach = function(client)
    -- Hover from ruff is noisy when basedpyright also provides one.
    client.server_capabilities.hoverProvider = false
  end,
}
