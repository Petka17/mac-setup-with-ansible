---@type vim.lsp.Config
return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    ".git",
  },
  on_init = function(client)
    -- If the project ships its own .luarc.json, defer to it.
    if client.workspace_folders then
      local path = client.workspace_folders[1].name

      if vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc") then
        return
      end
    end

    -- Default for projects without .luarc.json (rare for us).
    client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" },
      },
    })
  end,
  settings = {
    Lua = {
      codeLens = { enable = true },
      hint = { enable = true, semicolon = "Disable" },
      format = { enable = false }, -- stylua wins
    },
  },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
