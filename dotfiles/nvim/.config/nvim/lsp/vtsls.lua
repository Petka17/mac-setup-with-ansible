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

    -- TS7 projects on @effect/tsgo use the native LSP (see lsp/effect_tsgo.lua).
    -- vtsls wraps the classic tsserver TS7 dropped, so stay out of their way.
    if js_project.is_effect_tsgo_project(bufnr) then
      return
    end

    local root = js_project.npm_project_root(bufnr)
    if root then
      on_dir(root)
    end
  end,
  settings = {
    typescript = {
      -- Default tsserver heap cap is 3072 MB, which OOM-crashes tsserver on huge
      -- monorepos (the "language service crashed 5 times" prompt). vtsls passes
      -- this through as --max-old-space-size to the tsserver process, same as
      -- VSCode's typescript.tsserver.maxTsServerMemory. Raise further if needed.
      tsserver = { maxTsServerMemory = 12288 },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      preferences = {
        -- Default "shortest" gives a good mix. Use <leader>ti (or :VtslsToggleImportStyle)
        -- to flip to "non-relative" (and back) at runtime. No server restart required.
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
      preferences = {
        importModuleSpecifier = "shortest", -- kept in sync by toggle
      },
    },
    vtsls = {
      autoUseWorkspaceTsdk = true,
      experimental = {
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Make sure vtsls never advertises auto formatting to the format-on-save resolver.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false

    -- Import-style toggle logic lives in lua/lsp/ts_import_style.lua so vtsls and
    -- the native effect_tsgo server share one implementation. Both flip
    -- importModuleSpecifier via workspace/didChangeConfiguration, no restart.
    local import_style = require("lsp.ts_import_style")

    vim.api.nvim_buf_create_user_command(bufnr, "VtslsToggleImportStyle", function()
      import_style.toggle(bufnr)
    end, {
      desc = "Toggle vtsls typescript.preferences.importModuleSpecifier (shortest ↔ non-relative)",
    })
    vim.api.nvim_buf_create_user_command(bufnr, "VtslsShowImportStyle", function()
      import_style.show(bufnr)
    end, { desc = "Show current vtsls importModuleSpecifier setting" })
  end,
}
