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

    ---Toggle importModuleSpecifier preference between "shortest" and "non-relative"
    ---for all vtsls clients attached to this buffer.
    ---Uses workspace/didChangeConfiguration so no LSP restart is required.
    ---The change affects new auto-import suggestions and organize imports immediately.
    local function toggle_import_style()
      local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "vtsls" })
      if #clients == 0 then
        vim.notify("No vtsls client attached", vim.log.levels.WARN)
        return
      end

      -- Determine the style to switch *to* based on the first client we see.
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
          settings = {
            typescript = ts,
            javascript = js,
          },
        })
      end

      vim.notify("vtsls import style → " .. next_style, vim.log.levels.INFO)
    end

    local function show_import_style()
      local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "vtsls" })
      if #clients == 0 then
        vim.notify("No vtsls client attached", vim.log.levels.WARN)
        return
      end
      local ts = (clients[1].settings or {}).typescript or {}
      local style = ((ts.preferences or {}).importModuleSpecifier or "non-relative")
      vim.notify("vtsls importModuleSpecifier: " .. style, vim.log.levels.INFO)
    end

    vim.api.nvim_buf_create_user_command(bufnr, "VtslsToggleImportStyle", toggle_import_style, {
      desc = "Toggle vtsls typescript.preferences.importModuleSpecifier (shortest ↔ non-relative)",
    })
    vim.api.nvim_buf_create_user_command(
      bufnr,
      "VtslsShowImportStyle",
      show_import_style,
      { desc = "Show current vtsls importModuleSpecifier setting" }
    )
  end,
}
