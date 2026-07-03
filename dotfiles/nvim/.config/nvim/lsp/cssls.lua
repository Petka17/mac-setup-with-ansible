-- vscode-css-language-server (Mason: css-lsp): completion, hover, and validation
-- for CSS/SCSS/LESS.
--
-- Formatting is owned by prettier via efm, so provideFormatter is off and the
-- formatting capabilities are disabled on attach to avoid double-formatting.
--
-- `lint.unknownAtRules = "ignore"` silences the built-in validator's false
-- positives on Tailwind/SCSS at-rules (@apply, @tailwind, @use, …); the real
-- linting for those is a project concern, not this server's job.
---@type vim.lsp.Config
local settings = {
  validate = true,
  lint = { unknownAtRules = "ignore" },
}

return {
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  init_options = { provideFormatter = false }, -- prettier (via efm) owns formatting
  root_markers = { ".git" },
  settings = {
    css = settings,
    scss = settings,
    less = settings,
  },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
