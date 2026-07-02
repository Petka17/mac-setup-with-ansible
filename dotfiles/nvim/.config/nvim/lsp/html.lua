-- vscode-html-language-server (Mason: html-lsp): tag completion, validation, and
-- embedded CSS/JS awareness.
--
-- Formatting is owned by prettier via efm, so provideFormatter is off and the
-- formatting capabilities are disabled on attach to avoid double-formatting.
---@type vim.lsp.Config
return {
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html", "htmlangular" },
  init_options = {
    provideFormatter = false,
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
  },
  root_markers = { ".git" },
  settings = {},
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
