-- yaml-language-server (Mason: yaml-language-server): schema-driven completion,
-- hover, and validation for YAML.
--
-- Formatting is owned by prettier via efm (yaml is in efm's filetypes), so the
-- server's own formatter is disabled and the formatting capabilities are turned
-- off on attach to avoid double-formatting.
--
-- Schemas: SchemaStore.nvim (lua/packages/schemastore.lua) supplies the public
-- YAML catalog (GitHub Actions, docker-compose, gitlab-ci, kubernetes, …). If the
-- plugin isn't available yet (e.g. mid-install on a fresh machine), fall back to a
-- small hand-picked set so validation still works.
--
-- `schemaStore.enable = false` (+ empty url) disables the server's *own* built-in
-- schema store so SchemaStore.nvim is the single source of catalog schemas — the
-- two otherwise double up. Explicit `$schema`/modeline schemas in a file still win.
local ok, schemastore = pcall(require, "schemastore")
local schemas = ok and schemastore.yaml.schemas()
  or {
    ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
    ["https://json.schemastore.org/github-action.json"] = "/action.{yml,yaml}",
    ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.{yml,yaml}",
    ["https://json.schemastore.org/gitlab-ci.json"] = "*gitlab-ci*.{yml,yaml}",
  }

---@type vim.lsp.Config
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  root_markers = { ".git" },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      validate = true,
      format = { enable = false }, -- prettier (via efm) owns formatting
      -- Let SchemaStore.nvim (below) own the catalog; disable the server's own.
      schemaStore = { enable = false, url = "" },
      schemas = schemas,
    },
  },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
