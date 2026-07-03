---@type vim.lsp.Config
return {
  cmd = { "bash-language-server", "start" },
  filetypes = { "bash", "sh" },
  root_markers = { ".git" },
  settings = {
    bashIde = {
      -- Files bash-language-server treats as sources for cross-file analysis.
      globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.inc|.bash|.command)",
      -- Use shellcheck binary on PATH (Mason has installed it).
      shellcheckPath = "shellcheck",
    },
  },
}
