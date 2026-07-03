-- marksman: Markdown LSP (hover, link navigation, document outline).
-- Formatting is owned by prettier via efm, so we disable marksman's own
-- formatting capability to keep the format resolver unambiguous.
---@type vim.lsp.Config
return {
  cmd = { "marksman", "server" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = { ".marksman.toml", ".git" },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
