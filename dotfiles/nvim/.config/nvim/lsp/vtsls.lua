local js_project = require("lsp.js_project")

---@type vim.lsp.Config
return {
  cmd = { "vtsls", "--stdio" },
  init_options = { hostInfo = "neovim" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_dir = function(bufnr, on_dir)
    if js_project.is_deno_project(bufnr) then
      return
    end

    local root = js_project.npm_project_root(bufnr)
    if root then
      on_dir(root)
    end
  end,
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      preferences = {
        importModuleSpecifier = "shortest",
        includePackageJsonAutoImports = "auto",
      },
      updateImportsOnFileMove = { enabled = "always" },
    },
    javascript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
      },
    },
    vtsls = {
      experimental = {
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
  },
  on_attach = function(client, _)
    -- Make sure vtsls never advertises auto formatting to the format-on-save resolver.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
