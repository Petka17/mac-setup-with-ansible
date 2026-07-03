-- JS/TS format-on-save pipeline
--
-- Unlike the generic single-winner resolver in lsp/format.lua, this runs *every*
-- tool that is available for the buffer, in a fixed order, with no early exit:
--
--   1. eslint   -> source.fixAll.eslint   (LSP code action)
--   2. oxlint   -> source.fixAll.oxc      (LSP code action)
--   3. biome    -> biome format           (CLI, stdin)
--   4. dprint   -> dprint fmt             (CLI, stdin)
--   5. oxfmt    -> oxfmt                  (CLI, stdin)
--   6. prettier -> prettier              (CLI, stdin)
--
-- Lint-fixers run first so the buffer always ends formatted. If two formatters
-- happen to match (rare), both run and the later one in the order wins — a
-- deterministic, accepted trade-off. Everything runs synchronously inside
-- BufWritePre, before the write hits disk.

local code_action = require("lsp.code_action")

local M = {}

-- Directories from `start` up to the filesystem root, `start` first.
local function dirs_upward(start)
  local dirs = { start }
  for dir in vim.fs.parents(start) do
    dirs[#dirs + 1] = dir
  end
  return dirs
end

-- Directory the buffer lives in (cwd fallback for unnamed/scratch buffers).
local function buf_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return vim.fn.getcwd()
  end
  return vim.fs.dirname(name)
end

-- Resolve a CLI tool: prefer a project-local node_modules/.bin copy (walking up
-- from the buffer), then fall back to $PATH. Mirrors lsp/vtsls.lua's local-first
-- binary preference.
local function resolve_bin(bufnr, name)
  for _, dir in ipairs(dirs_upward(buf_dir(bufnr))) do
    local cand = dir .. "/node_modules/.bin/" .. name
    if vim.fn.executable(cand) == 1 then
      return cand
    end
  end
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  return nil
end

-- Directory of the nearest config file matching any marker, or nil. Doubles as
-- the "is this tool configured for this project" check and the cwd to run the
-- tool from (dprint/biome/etc. discover their config from cwd).
local function config_dir(bufnr, markers)
  local found = vim.fs.find(markers, { path = buf_dir(bufnr), upward = true })[1]
  return found and vim.fs.dirname(found) or nil
end

-- Directory of the nearest package.json that declares a top-level `field` key
-- (e.g. "prettier" / "oxfmt"), or nil.
local function pkg_field_dir(bufnr, field)
  local pkgs = vim.fs.find("package.json", {
    path = buf_dir(bufnr),
    upward = true,
    limit = math.huge,
  })
  for _, pkg in ipairs(pkgs) do
    local fh = io.open(pkg, "r")
    if fh then
      local content = fh:read("*a")
      fh:close()
      if content and content:match('"' .. field .. '"%s*:') then
        return vim.fs.dirname(pkg)
      end
    end
  end
  return nil
end

-- Format the buffer through a CLI tool: pipe the buffer on stdin, run from `cwd`
-- so config discovery works, and replace the buffer with stdout on success.
-- Leaves the buffer untouched (and notifies) on non-zero exit.
local function format_stdin(bufnr, argv, cwd)
  local input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  local res = vim.system(argv, { stdin = input, cwd = cwd, text = true }):wait()

  if res.code ~= 0 then
    local msg = (res.stderr or ""):gsub("%s+$", "")
    vim.notify(
      ("%s: %s"):format(argv[1], msg ~= "" and msg or "exit " .. res.code),
      vim.log.levels.WARN
    )
    return
  end

  local out = res.stdout
  if not out or out == "" then
    return
  end

  local new_lines = vim.split((out:gsub("\n$", "")), "\n", { plain = true })
  if vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), new_lines) then
    return
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  vim.fn.winrestview(view)
end

-- Raw LSP diagnostics a client has published for the buffer. The oxc / eslint
-- servers build their fixAll edit from the diagnostics handed to them in the
-- request context, so passing an empty list yields *no* action — we must feed
-- back the client's own diagnostics.
local function client_lsp_diagnostics(bufnr, client)
  local namespaces = {}
  local ok_pull, pull = pcall(vim.lsp.diagnostic.get_namespace, client.id, true)
  local ok_push, push = pcall(vim.lsp.diagnostic.get_namespace, client.id, false)
  if ok_pull then
    namespaces[pull] = true
  end
  if ok_push then
    namespaces[push] = true
  end

  local raw = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    if
      d.user_data
      and d.user_data.lsp
      and (vim.tbl_isempty(namespaces) or namespaces[d.namespace])
    then
      raw[#raw + 1] = d.user_data.lsp
    end
  end
  return raw
end

-- Apply an LSP `source.fixAll.*` code action synchronously. No-op if no client
-- named `client_name` is attached to the buffer (that absence *is* the
-- "tool not present" signal, since these servers only attach per project type).
-- eslint/oxlint build their fixAll edit from the diagnostics passed in context,
-- so we feed back the client's own diagnostics.
local function fix_all(bufnr, client_name, kind)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = client_name })[1]
  if not client then
    return
  end
  code_action.apply(bufnr, client, kind, client_lsp_diagnostics(bufnr, client))
end

-- Prettier auto-detects most of these; we only need one to prove intent.
local prettier_markers = {
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
}

-- CLI formatter steps, in run order. `dir(bufnr)` returns the project dir when
-- the tool is configured (and doubles as cwd), else nil.
local cli_steps = {
  {
    bin = "biome",
    dir = function(b)
      return config_dir(b, { "biome.json", "biome.jsonc" })
    end,
    argv = function(bin, file)
      return { bin, "format", "--stdin-file-path=" .. file }
    end,
  },
  {
    bin = "dprint",
    dir = function(b)
      return config_dir(b, { "dprint.json", "dprint.jsonc", ".dprint.json", ".dprint.jsonc" })
    end,
    argv = function(bin, file)
      return { bin, "fmt", "--stdin", file }
    end,
  },
  {
    bin = "oxfmt",
    dir = function(b)
      return config_dir(b, { ".oxfmtrc.json", ".oxfmtrc.jsonc" }) or pkg_field_dir(b, "oxfmt")
    end,
    argv = function(bin, file)
      return { bin, "--stdin-filepath=" .. file }
    end,
  },
  {
    bin = "prettier",
    dir = function(b)
      return config_dir(b, prettier_markers) or pkg_field_dir(b, "prettier")
    end,
    argv = function(bin, file)
      return { bin, "--stdin-filepath=" .. file }
    end,
  },
}

---Run the full JS/TS format pipeline on a buffer.
---@param bufnr integer
function M.run(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- 1-2: lint autofixes first, so any formatter below sees the fixed code.
  fix_all(bufnr, "eslint", "source.fixAll.eslint")
  fix_all(bufnr, "oxlint", "source.fixAll.oxc")

  -- 3-6: formatters. Need a real filename so the tool can pick a parser.
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return
  end

  for _, step in ipairs(cli_steps) do
    local dir = step.dir(bufnr)
    if dir then
      local bin = resolve_bin(bufnr, step.bin)
      if bin then
        format_stdin(bufnr, step.argv(bin, file), dir)
      end
    end
  end
end

return M
