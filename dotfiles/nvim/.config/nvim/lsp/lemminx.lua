-- lemminx: XML LSP. Unlike the other markup servers, lemminx is BOTH the
-- completion/validation provider AND the formatter for XML — prettier has no XML
-- support. So we keep its formatting on and register it with the format resolver
-- (see lua/lsp/init.lua).
---@type vim.lsp.Config
return {
  cmd = { "lemminx" },
  filetypes = { "xml", "xsd", "xsl", "xslt", "svg" },
  root_markers = { ".git" },
  settings = {
    xml = {
      format = {
        enabled = true,
        splitAttributes = false,
        joinCDATALines = false,
        joinCommentLines = false,
        formatComments = true,
        joinContentLines = false,
        spaceBeforeEmptyCloseTag = true,
      },
      validation = {
        enabled = true,
        resolveExternalEntities = false,
      },
    },
  },
}
