-- basedpyright: Python language intelligence (completions, hover, jumps,
-- type checking).
--
-- Formatting and import-organizing are owned by ruff (see lsp/ruff.lua), so
-- basedpyright's own formatting capability is disabled on attach to keep the
-- format resolver unambiguous. The interpreter is inferred from the environment;
-- :LspPyrightSetPythonPath reconfigures it at runtime when needed.

---Reconfigure the attached basedpyright client(s) to use a specific interpreter.
---@param command table user-command opts; command.args is the python path
local function set_python_path(command)
  local path = command.args
  local clients = vim.lsp.get_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = "basedpyright",
  })
  for _, client in ipairs(clients) do
    client.settings =
      vim.tbl_deep_extend("force", client.settings or {}, { python = { pythonPath = path } })
    client:notify("workspace/didChangeConfiguration", { settings = nil })
  end
end

---@type vim.lsp.Config
return {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyrightconfig.json",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "standard",
      },
    },
  },
  on_attach = function(client, bufnr)
    -- ruff owns formatting + organizing imports.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false

    vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightOrganizeImports", function()
      client:request("workspace/executeCommand", {
        command = "basedpyright.organizeimports",
        arguments = { vim.uri_from_bufnr(bufnr) },
      }, nil, bufnr)
    end, { desc = "Organize Python imports" })

    vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", set_python_path, {
      desc = "Reconfigure basedpyright with the provided python path",
      nargs = 1,
      complete = "file",
    })
  end,
}
