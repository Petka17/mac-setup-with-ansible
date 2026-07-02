-- vscode-json-language-server (Mason: json-lsp): schema-driven completion and
-- validation for JSON/JSONC.
--
-- Formatting is owned by prettier via efm, so provideFormatter is off and the
-- formatting capabilities are disabled on attach.
--
-- Schemas: SchemaStore.nvim (lua/packages/schemastore.lua) supplies hundreds of
-- public schemas (package.json, tsconfig, GitHub Actions, dockerfile, …). If that
-- plugin isn't available yet (e.g. mid-install on a fresh machine), fall back to a
-- small hand-picked set so validation still works.
local ok, schemastore = pcall(require, "schemastore")
local schemas = ok and schemastore.json.schemas()
  or {
    { fileMatch = { "package.json" }, url = "https://json.schemastore.org/package.json" },
    {
      fileMatch = { "tsconfig*.json", "tsconfig.*.json" },
      url = "https://json.schemastore.org/tsconfig.json",
    },
    {
      fileMatch = { ".prettierrc", ".prettierrc.json" },
      url = "https://json.schemastore.org/prettierrc.json",
    },
    {
      fileMatch = { "biome.json", "biome.jsonc" },
      url = "https://biomejs.dev/schemas/latest/schema.json",
    },
  }

---@type vim.lsp.Config
return {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc", "json5" },
  init_options = { provideFormatter = false }, -- prettier (via efm) owns formatting
  root_markers = { ".git" },
  settings = {
    json = {
      validate = { enable = true },
      schemas = schemas,
    },
  },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
