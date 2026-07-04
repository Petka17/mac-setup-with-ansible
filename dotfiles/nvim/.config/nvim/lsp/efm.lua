-- efm-langserver wraps CLI linters/formatters and presents them as an LSP.
--
-- selene (Rust, no Lua-interpreter dependency) lints Lua. It reads stdin via
-- `-` and emits one grep-style line per diagnostic under --display-style quiet:
--   file.lua:1:7: warning[unused_variable]: foo is assigned a value, but never used
--
-- Config discovery is per-project, NOT hardcoded to this Neovim config: when
-- linting from stdin, selene searches upward from its CWD for `selene.toml`, and
-- efm runs it with CWD set to the LSP root_dir. We make `selene.toml` a root
-- marker (see root_markers below) so root_dir lands on the nearest selene.toml.
-- Result: a project that ships its own selene.toml gets its own rules/std, while
-- this Neovim config (which ships selene.toml -> neovim.yml at its root, teaching
-- selene the `vim` global) resolves correctly even though it's nested inside a
-- larger git repo. A Lua project with no selene.toml falls back to selene's
-- built-in lua51 std (so `vim` is correctly flagged as undefined there).
local selene = {
  prefix = "selene",
  lintCommand = "selene --display-style quiet --no-summary -",
  lintStdin = true,
  lintIgnoreExitCode = true,
  lintFormats = {
    "%f:%l:%c: %trror%m",
    "%f:%l:%c: %tarning%m",
  },
}

-- shfmt flags: -i 2 (2-space indent), -ci (indent switch cases), -bn
-- (binary ops at start of next line), -sr (space after redirect), -s (simplify).
-- efm only *formats* shell; ShellCheck linting is owned by bash-language-server
-- (see lsp/bashls.lua) to avoid duplicate diagnostics.
local shfmt = {
  formatCommand = "shfmt -i 2 -ci -bn -sr -s",
  formatStdin = true,
}

-- prettier formats the markup filetypes (json/jsonc/yaml/css/scss/less/html)
-- through efm. Gated on a prettier config being found upward via
-- rootMarkers, so a project only gets prettier when it opts in (same
-- config-gated philosophy as the JS/TS pipeline in lua/lsp/ts_format.lua). We do
-- NOT wire prettier for js/ts here — that path is owned by ts_format.lua, which
-- short-circuits the format resolver, so an efm entry would be dead weight and
-- make efm attach to every TS buffer needlessly. Markdown has its own entry
-- (prettier_md below). `${INPUT}` is efm's template for the real filename,
-- letting prettier pick a parser.
local prettier = {
  formatCommand = 'prettier --stdin-filepath "${INPUT}"',
  formatStdin = true,
  rootMarkers = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yaml",
    ".prettierrc.yml",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  },
}

-- Markdown gets its own prettier entry: ungated (no rootMarkers) and with
-- --prose-wrap never, so format-on-save reflows each paragraph back onto one
-- line instead of keeping authored mid-sentence breaks (prettier's default
-- proseWrap "preserve"). Unlike the config-gated `prettier` above, this runs on
-- EVERY markdown buffer — there's no per-project prettier config to opt into for
-- personal notes/READMEs, and unwrapping is the wanted default. Intentional
-- breaks survive: prettier keeps markdown hard breaks (trailing "  " or "\") and
-- never reflows code fences. --prose-wrap is a CLI flag, so it overrides any
-- proseWrap a project sets in its own prettier config.
local prettier_md = {
  formatCommand = 'prettier --prose-wrap never --stdin-filepath "${INPUT}"',
  formatStdin = true,
}

-- markdownlint (markdownlint-cli) lints markdown from stdin. It writes its
-- report to *stderr* (hence `2>&1`, since efm parses stdout) and exits non-zero
-- whenever it finds a violation (hence lintIgnoreExitCode).
--
-- We always hand it our own config (markdownlint.json at the nvim config root),
-- which disables MD013/line-length — line length is a style choice, not an error.
-- Per-project markdownlint configs are rare enough that a single global default is
-- simpler; `--config` also disables markdownlint's cwd config discovery, so this is
-- the one source of truth. Output line: `stdin:1:3 error MD019/... msg`.
local mdl_config = vim.fn.stdpath("config") .. "/markdownlint.json"
local markdownlint = {
  lintCommand = "markdownlint --stdin --config " .. mdl_config .. " 2>&1",
  lintStdin = true,
  lintIgnoreExitCode = true,
  lintFormats = { "%f:%l:%c %m", "%f:%l %m" },
}

-- kulala-fmt: the official .http/.rest formatter (Node CLI, installed
-- via Mason). `fix --stdin` reads the buffer on stdin and writes only the
-- formatted file to stdout (exit 0, nothing on stderr), so it plugs straight into
-- efm's stdin formatter contract. This is the format-on-save path for http files;
-- it flows through the same lsp.format resolver (efm registered at priority 90) as
-- shfmt/prettier, so :FormatDisable and <leader>af cover it too. Not gated on a
-- rootMarker — unlike prettier, there's no per-project kulala-fmt config to opt
-- into, so we always format http buffers.
local kulala_fmt = {
  formatCommand = "kulala-fmt fix --stdin",
  formatStdin = true,
}

-- SQL. sqls' built-in formatter panics on common Postgres syntax
-- ($1 params, ::casts, ON CONFLICT, RETURNING, CTEs) and errors the whole
-- request, so it silently does nothing on real files. We format SQL with
-- sql-formatter instead — the same tool (and dialect) dbout uses for its own
-- <leader>Df, so format-on-save and dbout's formatter produce identical output.
-- We invoke dbout's bundled copy directly (guaranteed present after its npm
-- install; see lua/packages/dbout.lua) rather than adding a second global
-- install that could drift in version. sql-formatter requires an explicit
-- dialect — the generic "sql" dialect can't even parse `::` casts — so we default
-- to postgresql (the DB this config targets); change --language for a different
-- default. Applies to every .sql buffer, connection or not.
local sql_formatter_bin = vim.fs.joinpath(
  vim.fn.stdpath("data"),
  "site/pack/core/opt/dbout.nvim/node_modules/.bin/sql-formatter"
)
-- Formatting rules, passed inline via `-c <json>` (the CLI accepts a JSON string,
-- not just a file path). Uppercase keywords/functions/data types; everything else
-- stays at sql-formatter's defaults. identifierCase is deliberately left at
-- "preserve": Postgres folds unquoted table/column names to lowercase, so
-- uppercasing them would be misleading (and would corrupt case-sensitive quoted
-- identifiers). Adjust here — see sql-formatter docs for the full option list
-- (tabWidth, indentStyle, expressionWidth, logicalOperatorNewline, …).
local sql_formatter_config = {
  keywordCase = "upper",
  functionCase = "upper",
  dataTypeCase = "upper",
}
local sql_formatter = {
  formatCommand = ("%s --language postgresql -c %s"):format(
    vim.fn.shellescape(sql_formatter_bin),
    vim.fn.shellescape(vim.json.encode(sql_formatter_config))
  ),
  formatStdin = true,
}

---@type vim.lsp.Config
return {
  cmd = { "efm-langserver" },
  filetypes = {
    "lua",
    "sh",
    "bash",
    "json",
    "jsonc",
    "yaml",
    "css",
    "scss",
    "less",
    "html",
    "markdown",
    "http",
    "sql",
  },
  -- `selene.toml` first so a project's (or this config's) selene config defines the
  -- root_dir = selene's CWD; `.git` is the general fallback. Nearest match wins.
  root_markers = { "selene.toml", ".git" },
  init_options = { documentFormatting = true }, -- shfmt/prettier format through efm
  settings = {
    rootMarkers = { "selene.toml", ".git/" },
    languages = {
      lua = { selene },
      sh = { shfmt },
      bash = { shfmt },
      json = { prettier },
      jsonc = { prettier },
      yaml = { prettier },
      css = { prettier },
      scss = { prettier },
      less = { prettier },
      html = { prettier },
      markdown = { prettier_md, markdownlint },
      http = { kulala_fmt },
      sql = { sql_formatter },
    },
  },
}
