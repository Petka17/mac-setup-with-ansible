-- SchemaStore.nvim ships a Lua table of the public JSON/YAML schema catalog
-- (package.json, tsconfig, GitHub Actions, dockerfile, eslint config, …).
-- lsp/jsonls.lua pulls `require("schemastore").json.schemas()` and lsp/yamlls.lua
-- pulls `require("schemastore").yaml.schemas()` from it.
vim.pack.add({
  { src = "https://github.com/b0o/SchemaStore.nvim" },
})
