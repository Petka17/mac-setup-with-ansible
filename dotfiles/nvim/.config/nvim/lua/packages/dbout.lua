-- Database. dbout.nvim (query runner) + sqls (SQL language server),
-- wired so that dbout is the single source of truth for connections.
--
-- dbout.nvim is a Node-backed SQL client: it manages its own connection store
-- (`:Dbout NewConnection` etc.), opens a "queryer" buffer, runs the selected
-- statement(s), and shows rows in a "viewer" split with a schema "inspector".
-- sqls provides the schema-aware *editing* intelligence (completion, hover,
-- go-to-definition) on those SQL buffers.
--
-- sqls does NOT format here: its built-in formatter panics on common Postgres
-- syntax ($1 params, ::casts, ON CONFLICT, RETURNING, CTEs) and returns an error
-- for the whole request, so it silently does nothing on real files. SQL
-- formatting is owned by sql-formatter via efm (see lsp/efm.lua) — the same tool
-- dbout uses for <leader>Df, so format-on-save and dbout's formatter agree.
--
-- Integration model:
-- sqls is NEVER generic-enabled. Instead, dbout's `on_attach` hook — which fires
-- per buffer whenever a connection is opened/attached and hands us the fully
-- resolved connection params — spawns a sqls instance *pinned* to that
-- connection via `initializationOptions.connectionConfig` (which makes sqls
-- ignore every other config source: no -config, no config.yml, no workspace
-- config). The instance is named `sqls:<connection>` so that:
--   * a second buffer on the same connection REUSES the instance (Neovim's
--     vim.lsp.start reuse-by-name), and
--   * different connections get independent instances (correct completion in
--     two buffers side by side).
-- Lifecycle (start lazily / reuse / stop when the last buffer leaves) is handled
-- by Neovim's own client bookkeeping plus the LspDetach handler below.

-- dbout's RPC layer treats *everything* the Node backend writes to stderr as a
-- JSON error object (rpc.lua `on_stderr` → vim.fn.json_decode). Node *process
-- warnings* — e.g. pg-connection-string's "SECURITY WARNING: sslmode 'require'…"
-- notice, emitted whenever a connection URL uses `sslmode=require` (as cloud
-- Postgres like Neon requires) — are plain text, so that json_decode throws
-- `E474: Unidentified byte` and the connection looks like it failed. Silencing
-- Node's process warnings keeps dbout's stderr JSON-only. Applies to all Node
-- child processes of this Nvim (LSP servers etc.); those warnings are just noise.
vim.env.NODE_NO_WARNINGS = "1"

vim.pack.add({
  { src = "https://github.com/zongben/dbout.nvim" },
})

-- Build the Node backend on first clone / update. vim.pack has no build hook, so
-- we run `npm install` from PackChanged. Async; guards on npm being on PATH.
vim.api.nvim_create_autocmd("PackChanged", {
  desc = "Build dbout.nvim Node backend (npm install)",
  group = vim.api.nvim_create_augroup("nightly-dbout-build", { clear = true }),
  callback = function(ev)
    local data = ev.data or {}
    local spec = data.spec
    if not spec or spec.name ~= "dbout.nvim" then
      return
    end
    if data.kind ~= "install" and data.kind ~= "update" then
      return
    end
    if vim.fn.executable("npm") == 0 then
      vim.notify("dbout.nvim: npm not found on PATH; backend not built", vim.log.levels.WARN)
      return
    end
    vim.notify("dbout.nvim: running npm install…", vim.log.levels.INFO)
    vim.system({ "npm", "install" }, { cwd = data.path, text = true }, function(out)
      vim.schedule(function()
        if out.code == 0 then
          vim.notify("dbout.nvim: npm install complete", vim.log.levels.INFO)
        else
          vim.notify("dbout.nvim: npm install failed\n" .. (out.stderr or ""), vim.log.levels.ERROR)
        end
      end)
    end)
  end,
})

local blink = require("packages.blink")

-- Client-name prefix that ties a sqls instance to a dbout connection.
local SQLS_PREFIX = "sqls:"

---Map dbout's connection info (resolved by its backend) to a sqls DBConfig.
---dbout `db_type` values (sqlite3/postgresql/mysql/mssql) match sqls driver
---names 1:1, so no translation table is needed.
---
---Postgres & sqlite pass dbout's raw connection string straight through as
---`dataSourceName` (sqls uses it verbatim — genPostgresConfig short-circuits on
---DataSourceName, and its pgx driver understands the `postgresql://…` URL incl.
---`sslmode`/`channel_binding`). This is REQUIRED for cloud Postgres like Neon:
---decomposing into discrete host/user/… fields drops the SSL params, so sqls
---would try a non-SSL connect, block in PingContext during `initialize`, and the
---client would tear down before it attaches. mysql/mssql keep discrete fields
---(dbout's and sqls' raw string formats differ there).
---@param conn table dbout on_attach payload
---@return table connectionConfig for sqls initializationOptions
local function build_conn_config(conn)
  if conn.db_type == "postgresql" then
    return { alias = conn.name, driver = "postgresql", dataSourceName = conn.connstr }
  end
  if conn.db_type == "sqlite3" then
    return {
      alias = conn.name,
      driver = "sqlite3",
      dataSourceName = (conn.database ~= "" and conn.database) or conn.connstr,
    }
  end
  -- mysql / mssql: prefer discrete fields resolved by dbout's backend; fall back
  -- to the raw connstr only if no host was resolved.
  if not conn.host or conn.host == "" then
    return { alias = conn.name, driver = conn.db_type, dataSourceName = conn.connstr }
  end
  return {
    alias = conn.name,
    driver = conn.db_type,
    proto = "tcp",
    user = conn.user,
    passwd = conn.password,
    host = conn.host,
    port = tonumber(conn.port),
    dbName = conn.database,
  }
end

---dbout on_attach: (re)point `bufnr` at a sqls instance pinned to `conn`.
---@param conn table { name, db_type, host, port, user, password, database, connstr }
---@param bufnr integer
local function attach_sqls(conn, bufnr)
  local name = SQLS_PREFIX .. conn.name

  -- Reconnect case: detach any *other* pinned sqls instance from this buffer so
  -- completion doesn't merge two connections. Detaching may leave the old
  -- instance with no buffers, which the LspDetach handler below then stops.
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if c.name ~= name and vim.startswith(c.name, SQLS_PREFIX) then
      vim.lsp.buf_detach_client(bufnr, c.id)
    end
  end

  -- Start (or reuse, by name) the pinned instance and attach it to this buffer.
  -- sqls' `initialize` connects to the DB and introspects the schema before it
  -- replies, so for a remote DB the client only becomes usable a few seconds
  -- later — the "LSP ready: <name>" notification (lua/lsp/init.lua, on LspAttach)
  -- marks that point.
  vim.lsp.start({
    name = name,
    cmd = { "sqls" },
    capabilities = blink.capabilities,
    init_options = { connectionConfig = build_conn_config(conn) },
  }, { bufnr = bufnr })
end

-- Stop a pinned sqls instance once its last buffer detaches (buffer closed, or
-- reconnected elsewhere). Neovim maintains client.attached_buffers but does NOT
-- auto-stop on last detach (only at exit), so we do it. LspDetach fires *before*
-- the buffer is removed from attached_buffers, hence the vim.schedule.
vim.api.nvim_create_autocmd("LspDetach", {
  desc = "Stop pinned sqls instance when its last buffer leaves",
  group = vim.api.nvim_create_augroup("nightly-dbout-sqls-lifecycle", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or not vim.startswith(client.name, SQLS_PREFIX) then
      return
    end
    vim.schedule(function()
      if not client:is_stopped() and next(client.attached_buffers) == nil then
        client:stop()
      end
    end)
  end,
})

-- Run only the statement under the cursor. dbout's own `query` action runs the
-- visual selection, or the WHOLE buffer in normal mode (queryer.lua
-- `visual_select`) — so out of the box you must visually select a statement to
-- run just it. This finds the statement bounds around the cursor by scanning for
-- the nearest `;` on either side (line granularity, matching dbout's own
-- line-based selection), emulates a linewise visual selection over those lines,
-- and invokes dbout's query path — reusing its tested backend/viewer wiring
-- rather than re-implementing the RPC. Bound per queryer buffer in on_attach.
local function query_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)[1] -- 1-based cursor row
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local n = #lines

  -- End: first line at/after the cursor that terminates a statement (`;`); if
  -- none (a trailing statement with no semicolon), run to end of buffer.
  local e = cur
  while e < n and not lines[e]:find(";", 1, true) do
    e = e + 1
  end
  -- Start: line just after the previous statement's terminator, else buffer top.
  local s = cur
  while s > 1 and not lines[s - 1]:find(";", 1, true) do
    s = s - 1
  end

  -- `noautocmd` so the transient visual selection doesn't fire mode/cursor
  -- autocmds; `\27` (<Esc>) leaves visual mode afterwards.
  vim.cmd(("noautocmd normal! %dGV%dG"):format(s, e))
  require("dbout.ui.queryer").query()
  vim.cmd("noautocmd normal! \27")
end

require("dbout").setup({
  -- Don't auto-open the schema inspector on connect: it's a read-only buffer of
  -- the table list rendered as raw JSON (inspector.lua sets filetype=json), which
  -- adds noise with little value. It stays available on demand via <leader>Di
  -- (toggle_inspector). The viewer (query results) keeps its default auto-open.
  ui = { init_open = { inspector = false } },
  -- Remap dbout's default function-key bindings onto this config's leader-based
  -- <leader>D ("Database") namespace. `query` mirrors kulala's <leader>Rs "send"
  -- mental model; <C-c> is avoided — it's bound to nohlsearch.
  keymaps = {
    global = {
      toggle_inspector = "<leader>Di",
      toggle_viewer = "<leader>Dv",
      close = "q",
    },
    queryer = {
      query = "<leader>DS", -- run visual selection (or whole buffer in normal mode)
      format = "<leader>Df", -- dbout's own sql-formatter for the queryer buffer
    },
    viewer = {
      -- dbout's default delete_history is <C-d>, which shadows the classic
      -- half-page-down in the result buffer. Move it to <C-r> ("remove") — the
      -- result buffer is read-only so <C-r> (redo) is a no-op there, and it avoids
      -- the window-nav keys (<C-h/j/k/l>), page motions (<C-d/u/f/b>), and <C-x>
      -- (reserved for opencode's menu). <C-d> thus falls back to standard.
      -- next_history "}" / previous_history "{" keep dbout defaults.
      delete_history = "<C-r>",
    },
    -- inspector keeps dbout defaults (H/L tabs).
  },
  -- The bridge: every connection open/attach pins a sqls instance to the buffer,
  -- and adds the "run statement under cursor" keymap to that queryer buffer.
  on_attach = function(conn, bufnr)
    attach_sqls(conn, bufnr)
    vim.keymap.set(
      "n",
      "<leader>Ds",
      query_under_cursor,
      { buffer = bufnr, desc = "dbout: run statement under cursor" }
    )
  end,
})

-- Connection management. dbout stores connections in its own local store; these
-- pickers are how you add/edit/select them.
vim.keymap.set(
  "n",
  "<leader>Do",
  "<cmd>Dbout OpenConnection<cr>",
  { desc = "dbout: open connection" }
)
vim.keymap.set(
  "n",
  "<leader>Dn",
  "<cmd>Dbout NewConnection<cr>",
  { desc = "dbout: new connection" }
)
vim.keymap.set(
  "n",
  "<leader>De",
  "<cmd>Dbout EditConnection<cr>",
  { desc = "dbout: edit connection" }
)
vim.keymap.set(
  "n",
  "<leader>Dx",
  "<cmd>Dbout DeleteConnection<cr>",
  { desc = "dbout: delete connection" }
)
vim.keymap.set(
  "n",
  "<leader>Da",
  "<cmd>Dbout AttachConnection<cr>",
  { desc = "dbout: attach connection to buffer" }
)
