-- hledger-lsp: account-name completion for hledger journals.
--
-- Opt-in / best-effort: hledger-lsp (https://github.com/juev/hledger-lsp, a Go
-- server) is not in Mason. This config is only *enabled* from lua/lsp/init.lua
-- when the binary is on PATH, and native vim.lsp already refuses to start a
-- server whose `cmd` isn't executable (see can_start -> validate_cmd), so a
-- missing binary is a silent no-op — no client, no error.
---@type vim.lsp.Config
return {
  -- Communicates over stdio by default; it takes no flags and (being a Go
  -- binary) exits on an undefined one, so pass the bare command.
  cmd = { "hledger-lsp" },
  filetypes = { "hledger", "ledger" },
  root_markers = { ".hledger-lsp.json", ".git" },
}
