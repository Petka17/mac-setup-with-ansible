-- oxlint's built-in language server (`oxlint --lsp`). Auto formatting uses it for its
-- `source.fixAll.oxc` code action, applied on save by lua/lsp/ts_format.lua
-- (step 2). It attaches only when an oxlint config is present, so "this client
-- is attached" == "oxlint is configured for this project".
--
-- Inline diagnostics come for free once attached. This file adds a manual `:LspOxlintFixAll`
-- command and opt-in type-aware linting. It does NOT add a BufWritePost fix-all autocmd —
-- auto formatting already runs oxc.fixAll on BufWritePre, and a post-write pass
-- would fix the buffer a second time.
--
-- The oxlint CLI serves the LSP itself — there is no separate oxc_language_server
-- binary. Prefer a project-local copy (resolved from the workspace root), then
-- the Mason/global one.
local function oxlint_conf_mentions_typescript(root_dir)
  if not root_dir then
    return false
  end
  local fh = io.open(vim.fs.joinpath(root_dir, ".oxlintrc.json"), "r")
  if not fh then
    return false
  end
  for line in fh:lines() do
    if line:find("typescript") then
      fh:close()
      return true
    end
  end
  fh:close()
  return false
end

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local bin = "oxlint"
    local local_bin = config
      and config.root_dir
      and (config.root_dir .. "/node_modules/.bin/oxlint")
    if local_bin and vim.fn.executable(local_bin) == 1 then
      bin = local_bin
    end
    return vim.lsp.rpc.start({ bin, "--lsp" }, dispatchers)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  workspace_required = true,
  root_markers = { ".oxlintrc.json", "oxlintrc.json", ".oxlint.json", "oxlint.config.ts" },
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "LspOxlintFixAll", function()
      client:exec_cmd({
        title = "Apply Oxlint automatic fixes",
        command = "oxc.fixAll",
        arguments = { { uri = vim.uri_from_bufnr(bufnr) } },
      })
    end, { desc = "Apply Oxlint automatic fixes" })
  end,
  -- Opt into oxlint's type-aware rules when the project asks for TypeScript and
  -- the `tsgolint` helper is on PATH. Harmless no-op otherwise.
  before_init = function(init_params, config)
    local settings = config.settings or {}
    if settings.typeAware == nil and vim.fn.executable("tsgolint") == 1 then
      local ok, res = pcall(oxlint_conf_mentions_typescript, config.root_dir)
      if ok and res then
        settings = vim.tbl_extend("force", settings, { typeAware = true })
      end
    end
    local init_options = config.init_options or {}
    init_options.settings =
      vim.tbl_extend("force", init_options.settings or {} --[[@as table]], settings)
    init_params.initializationOptions = init_options
  end,
}
