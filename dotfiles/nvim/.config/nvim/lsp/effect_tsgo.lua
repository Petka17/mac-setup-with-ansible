-- TypeScript 7 native language server for @effect/tsgo projects.
--
-- TS7's native (Go) compiler speaks LSP directly (`tsc --lsp --stdio`) and no
-- longer ships the classic tsserver.js that vtsls/ts_ls wrap — so those servers
-- return null hovers on a TS7 project. @effect/tsgo patches the Effect Language
-- Service into that native binary, so this one server gives both TS7 intelligence
-- and Effect diagnostics/quick-fixes.
--
-- Attaches only when the project is effect-tsgo-managed (see
-- js_project.effect_tsgo_launcher); vtsls skips those same projects, so exactly
-- one TS server spawns per buffer. Project-local only — nothing to install via
-- Mason; if the launcher is absent, root_dir never fires on_dir and no client
-- starts.
local js_project = require("lsp.js_project")

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    -- root_dir only calls on_dir for effect-tsgo projects, so the launcher
    -- resolves here. Kept local-first, mirroring lsp/oxlint.lua.
    local launcher = config and config.root_dir and js_project.effect_tsgo_launcher(config.root_dir)
    return vim.lsp.rpc.start({ launcher, "--lsp", "--stdio" }, dispatchers)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  -- Don't spawn for scratch buffers outside a project.
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    if js_project.is_deno_project(bufnr) then
      return
    end
    local root = js_project.npm_project_root(bufnr)
    if root and js_project.effect_tsgo_launcher(root) then
      on_dir(root)
    end
  end,
  -- The native server aims for the same workspace-config shape as VS Code's TS
  -- support. Mirrors the inlay-hint / import preferences from lsp/vtsls.lua;
  -- unsupported keys are ignored by the server rather than erroring.
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
      preferences = {
        importModuleSpecifier = "shortest",
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Formatting stays with the format-on-save pipeline (oxfmt/prettier), never
    -- the TS server — same policy as lsp/vtsls.lua.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false

    -- Import-style toggle, shared with vtsls (see lua/lsp/ts_import_style.lua).
    -- The <leader>ti keymap is wired in lua/lsp/init.lua; these commands give the
    -- same thing on the : command-line, paralleling vtsls's :Vtsls* commands.
    local import_style = require("lsp.ts_import_style")

    vim.api.nvim_buf_create_user_command(bufnr, "TsToggleImportStyle", function()
      import_style.toggle(bufnr)
    end, {
      desc = "Toggle typescript.preferences.importModuleSpecifier (shortest ↔ non-relative)",
    })
    vim.api.nvim_buf_create_user_command(bufnr, "TsShowImportStyle", function()
      import_style.show(bufnr)
    end, { desc = "Show current importModuleSpecifier setting" })
  end,
}
