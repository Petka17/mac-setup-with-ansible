-- Biome language server (`biome lsp-proxy`).
--
-- Autoformatting already runs `biome format` as a CLI formatter on save (see
-- lua/lsp/ts_format.lua) — it does NOT attach an LSP. This file attaches biome's
-- LSP purely for its inline *lint* diagnostics.
-- biome is not registered in the format priority resolver, and the
-- JS/TS save path skips that resolver anyway, so there is no double-format.
--
-- Attaches only when a biome config is present, so "attached" == "biome is
-- configured for this project". Prefer a project-local copy, then Mason/global.
---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local bin = "biome"
    local local_bin = config and config.root_dir and (config.root_dir .. "/node_modules/.bin/biome")
    if local_bin and vim.fn.executable(local_bin) == 1 then
      bin = local_bin
    end
    return vim.lsp.rpc.start({ bin, "lsp-proxy" }, dispatchers)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  workspace_required = true,
  root_markers = { "biome.json", "biome.jsonc" },
}
