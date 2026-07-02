-- REST client via kulala.nvim.
--
-- Edit .http / .rest files, send the request under the cursor, read the response
-- in a split — a Postman replacement that lives in version control as plain text.
--
-- Treesitter: kulala ships and self-manages its own `kulala_http` grammar
-- (treesitter.enable is true by default; the parser is built with the
-- `tree-sitter` CLI installed by tasks/nvim.yml). That grammar is richer than the
-- registry `http` parser — it understands kulala's variables, gRPC/GraphQL and
-- request scripts. The FileType autocmd below starts `kulala_http` and falls back
-- to the registry `http` parser (installed in packages/treesitter.lua) if the
-- bundled one hasn't been built yet.

vim.pack.add({
  { src = "https://github.com/mistweaverco/kulala.nvim" },
})

require("kulala").setup({
  -- Install kulala's global keymaps under <leader>R (its own default prefix,
  -- consistent with this config's leader-based bindings — e.g. neogit on
  -- <leader>g). NOT <C-c>: that key is already nohlsearch in lua/keymaps.lua.
  --   <leader>Rs  send request under cursor      <leader>Rn  next request
  --   <leader>Ra  send all requests              <leader>Rp  previous request
  --   <leader>Ri  inspect (verbose) view         <leader>Rt  toggle view
  global_keymaps = true,
  global_keymaps_prefix = "<leader>R",
  default_env = "dev",
  ui = {
    default_view = "headers_body",
    winbar = true,
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "http",
  desc = "Start kulala treesitter parser on .http buffers",
  group = vim.api.nvim_create_augroup("nightly-kulala-http", { clear = true }),
  callback = function(args)
    local ok = pcall(vim.treesitter.start, args.buf, "kulala_http")
    if not ok then
      pcall(vim.treesitter.start, args.buf, "http")
    end
  end,
})
