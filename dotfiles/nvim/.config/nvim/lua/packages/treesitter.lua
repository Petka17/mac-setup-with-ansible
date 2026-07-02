-- Pin to `main` explicitly. This file uses main-branch-only APIs
-- (setup({ install_dir }), .install(), .indentexpr()) — the rewrite, not the
-- legacy `master` branch. Without this we ride whatever the repo's default
-- branch happens to be, so a default-branch change upstream (or a checkout that
-- lands on master) would break the whole module silently.
vim.pack.add({
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

-- nvim-treesitter main branch (the rewrite): setup() only reads `install_dir`.
-- Highlight is enabled per-buffer via vim.treesitter.start() in the autocmd below;
-- indent is enabled per-buffer via vim.bo.indentexpr. Folds use vim.treesitter.foldexpr()
-- (set in lua/options.lua).
require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

-- "Ensure installed" — main-branch equivalent of the old ensure_installed table.
-- install() is async and idempotent (no-op when the parser is already installed),
-- so a fresh machine self-bootstraps on first launch without blocking startup
-- thereafter.
require("nvim-treesitter").install({
  -- Editor / Vim
  "lua",
  "vim",
  "vimdoc",
  "query",
  -- Web stack
  "typescript",
  "tsx",
  "javascript",
  -- Systems / scripting
  "python",
  "rust",
  "go",
  "bash",
  -- Data / config
  "json",
  "yaml",
  "toml",
  -- Markup
  "html",
  "css",
  "markdown",
  "markdown_inline",
  -- Misc
  "sql",
  "dockerfile",
  "regex",
  "diff",
  "gitcommit",
  "git_rebase",
  "ledger",
  "http",
  "graphql", -- gql`...` tagged templates
  "comment", -- TODO / FIXME / NOTE etc. inside code comments
  "jsdoc", -- /** @param ... */ blocks
  "styled", -- styled.div`...`, styled(Foo)`...`
})

-- Filetype aliases so the same parser handles related extensions.
vim.treesitter.language.register("ledger", "hledger")
vim.treesitter.language.register("robots_txt", "robots")

-- Map .journal to hledger so the parser kicks in.
vim.filetype.add({
  extension = {
    journal = "hledger",
    hledger = "hledger",
  },
})

-- Start the parser on every loaded buffer that has one available.
-- Skip plugin UI buffers and netrw.
vim.api.nvim_create_autocmd("FileType", {
  desc = "Activate Treesitter parser on FileType",
  group = vim.api.nvim_create_augroup("nightly-treesitter-start", { clear = true }),
  callback = function(args)
    if not vim.api.nvim_buf_is_loaded(args.buf) then
      return
    end

    if vim.b[args.buf].large_buf then
      return -- large-file guard: no highlight/indent on oversized buffers
    end

    local filetype = vim.bo[args.buf].filetype

    if
      filetype == ""
      or filetype == "netrw"
      or filetype == "text"
      or filetype:match("^Telescope")
      or filetype:match("^Neogit")
    then
      return
    end

    local lang = vim.treesitter.language.get_lang(filetype)
    if not lang then
      return
    end

    local ok, parser = pcall(vim.treesitter.get_parser, args.buf, lang, { error = false })
    if ok and parser then
      pcall(vim.treesitter.start, args.buf, lang)
      -- Treesitter-based indent (experimental upstream). Quotes are load-bearing —
      -- the value is a Vim expression that Neovim evaluates for 'indentexpr'.
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
