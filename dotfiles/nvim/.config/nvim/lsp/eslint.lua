-- ESLint language server (from the `eslint-lsp` Mason package).
--
-- First formatting attaches this for its `source.fixAll.eslint` code action (applied on
-- save by lua/lsp/ts_format.lua, step 1). Then setup keeps that intact and layers
-- on the *linting* concerns: inline diagnostics come for free once attached, and
-- this file adds the attach gating (deno guard via lsp.js_project), eslint-9 flat-config detection,
-- Yarn PnP support, the server's `eslint/*` handlers, and a manual
-- `:LspEslintFixAll` command.
-- We do NOT set `format = true` or register eslint in the priority resolver
-- (the JS/TS save path short-circuits the resolver entirely; see lua/lsp/format.lua).
--
-- Prefer a project-local eslint server, then the Mason/global one.
local js_project = require("lsp.js_project")

local eslint_config_files = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local bin = "vscode-eslint-language-server"
    local local_bin = config
      and config.root_dir
      and (config.root_dir .. "/node_modules/.bin/vscode-eslint-language-server")
    if local_bin and vim.fn.executable(local_bin) == 1 then
      bin = local_bin
    end
    local argv = { bin, "--stdio" }
    -- before_init sets _yarn_pnp when .pnp.cjs/.pnp.js is present at root_dir.
    if config._yarn_pnp then
      argv = vim.list_extend({ "yarn", "exec" }, argv)
    end
    return vim.lsp.rpc.start(argv, dispatchers)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  workspace_required = true,
  -- A function root_dir (instead of root_markers) so we can (a) skip Deno
  -- projects, which use deno_lint rather than eslint, and (b) still gate on an
  -- eslint config being present — attach only where one is found upward, rooting
  -- at its directory. "eslint client attached" therefore still means "eslint is
  -- configured for this project".
  root_dir = function(bufnr, on_dir)
    if js_project.is_deno_project(bufnr) then
      return
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
    local cfg = vim.fs.find(eslint_config_files, { path = start, upward = true })[1]
    if cfg then
      on_dir(vim.fs.dirname(cfg))
    end
  end,
  -- The vscode-eslint server pulls per-document config via workspace/configuration
  -- and calls Node `path` helpers with several of these fields; leaving them unset
  -- makes it pass `undefined` and throw `The "path" argument must be of type
  -- string`. This mirrors nvim-lspconfig's known-good defaults. `useFlatConfig`
  -- defaults false (legacy CLIEngine path); before_init flips it on when a flat
  -- config file is detected.
  settings = {
    validate = "on",
    format = false,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = { shortenToSingleLine = false },
    nodePath = "",
    useESLintClass = false,
    experimental = { useFlatConfig = false },
    codeActionOnSave = { enable = false, mode = "all" },
    workingDirectory = { mode = "location" },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
  },
  -- root_dir isn't known until attach, so finalise the root-derived settings here:
  -- the server's own `settings.workspaceFolder` (needed for path resolution — see
  -- settings note), flat-config detection, and Yarn PnP wrapping.
  before_init = function(_, config)
    local root_dir = config.root_dir
    if not root_dir then
      return
    end

    config.settings = config.settings or {}
    config.settings.workspaceFolder = {
      uri = vim.uri_from_fname(root_dir),
      name = vim.fn.fnamemodify(root_dir, ":t"),
    }

    -- Detect a flat config (eslint 9+) in the root, ignoring node_modules.
    for _, file in ipairs(eslint_config_files) do
      if file:match("config") then
        local found = vim.fn.globpath(root_dir, file, true, true)
        local filtered = vim.tbl_filter(function(f)
          return not f:find("[/\\]node_modules[/\\]")
        end, found)
        if #filtered > 0 then
          config.settings.experimental = { useFlatConfig = true }
          break
        end
      end
    end

    -- Yarn PnP: the cmd function reads this flag and prefixes `yarn exec`.
    if vim.uv.fs_stat(root_dir .. "/.pnp.cjs") or vim.uv.fs_stat(root_dir .. "/.pnp.js") then
      config._yarn_pnp = true
    end
  end,
  on_attach = function(client, bufnr)
    -- Ad-hoc fix-all, for manual runs. Format-on-save already applies
    -- source.fixAll.eslint via auto formatting pipeline, so this is not wired to save.
    vim.api.nvim_buf_create_user_command(bufnr, "LspEslintFixAll", function()
      client:request_sync("workspace/executeCommand", {
        command = "eslint.applyAllFixes",
        arguments = {
          { uri = vim.uri_from_bufnr(bufnr), version = vim.lsp.util.buf_versions[bufnr] },
        },
      }, nil, bufnr)
    end, { desc = "Apply all ESLint fixes" })
  end,
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        vim.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function(_, result)
      if not result then
        return
      end
      return 4 -- approved
    end,
    ["eslint/probeFailed"] = function()
      vim.notify("ESLint probe failed.", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      vim.notify("Unable to find ESLint library.", vim.log.levels.WARN)
      return {}
    end,
  },
}
