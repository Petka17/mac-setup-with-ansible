-- taplo (Mason: taplo): the canonical TOML language server. One binary covers
-- everything TOML needs here — completion, hover, format-on-save formatting, and
-- diagnostics (syntax errors plus JSON-schema validation).
--
-- Unlike jsonls/yamlls, formatting is left enabled: taplo IS the TOML formatter
-- (prettier core has no TOML support), so it owns the format-on-save path and is
-- registered in the priority resolver (see lua/lsp/init.lua).
--
-- Schemas: taplo ships its own TOML catalog and resolves schemas for well-known
-- files (Cargo.toml, pyproject.toml, …) plus inline `#:schema` directives, so —
-- unlike jsonls/yamlls — it does NOT pull from SchemaStore.nvim. `schema.enabled`
-- turns that validation on; that's the "linting" beyond bare syntax checking.
--
-- `.taplo.toml` is a root marker (like selene.toml in lsp/efm.lua) so a project
-- shipping its own taplo config roots there and gets its own formatting rules;
-- `.git` is the general fallback.

---@type vim.lsp.Config
return {
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
  root_markers = { ".taplo.toml", ".git" },
  settings = {
    schema = { enabled = true },
  },
}
