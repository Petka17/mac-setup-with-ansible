vim.pack.add({
  {
    src = "https://github.com/Saghen/blink.cmp",
    version = vim.version.range("1.*"),
  },
})

local blink = require("blink.cmp")

blink.setup({
  keymap = {
    preset = "default",
    ["<CR>"] = { "accept", "fallback" },
    -- macOS binds <C-Space> to the input-source switcher, so trigger completion
    -- with the native insert-completion chord instead. This shadows built-in
    -- omni-completion (i_CTRL-X_CTRL-O), which blink supersedes anyway; other
    -- <C-x>… native completions still work after 'timeoutlen'.
    ["<C-x><C-o>"] = { "show", "show_documentation", "hide_documentation" },
    ["<C-e>"] = { "hide", "fallback" },
    ["<Tab>"] = { "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "snippet_backward", "fallback" },
  },
  appearance = {
    nerd_font_variant = "mono",
  },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    ghost_text = { enabled = false },
    list = { selection = { preselect = false, auto_insert = true } },
    menu = { border = "rounded", draw = { treesitter = { "lsp" } } },
  },
  signature = { enabled = true, window = { border = "rounded" } },
  -- Command-line completion. blink ships cmdline enabled but with the popup menu
  -- on-demand (only after <Tab>); flip auto_show so completions appear as you
  -- type. The "cmdline" keymap preset (<Tab> to select, <CR> to accept/execute)
  -- replaces the insert-mode "default" preset above only while in cmdline mode.
  -- Default cmdline sources already resolve to { cmdline, path } for `:` and
  -- { buffer } for `/`,`?`, so we don't override `sources` here.
  cmdline = {
    keymap = { preset = "cmdline" },
    completion = {
      menu = { auto_show = true },
      list = { selection = { preselect = false, auto_insert = true } },
    },
  },
  snippets = { preset = "luasnip" },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
    providers = {
      lsp = { score_offset = 100 },
      snippets = { score_offset = 80 },
      path = { score_offset = 60 },
      buffer = { score_offset = 40 },
    },
  },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})

-- Capabilities table consumed by every lsp/<server>.lua via the
-- LspAttach hook in lua/lsp/init.lua.
return {
  capabilities = blink.get_lsp_capabilities(),
}
