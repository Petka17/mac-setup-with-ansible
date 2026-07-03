-- LSP hub. Loads after packages installation complete so blink.cmp is available.
--
-- Each language server is a file at <config>/lsp/<name>.lua (project root,
-- NOT under lua/). That convention is what Neovim's vim.lsp.config(name)
-- auto-discovers.

local blink = require("packages.blink")
local format = require("lsp.format")

-- Mason tools.
require("packages.mason").ensure(
  "lua-language-server",
  "stylua",
  "efm",
  "selene",
  "bash-language-server",
  "shfmt",
  "shellcheck",
  "vtsls",
  "oxlint",
  "eslint-lsp",
  "biome",
  "dprint",
  "prettier",
  "oxfmt",
  "marksman",
  "json-lsp",
  "html-lsp",
  "css-lsp",
  "yaml-language-server",
  "lemminx",
  "markdownlint",
  "basedpyright",
  "ruff",
  "kulala-fmt",
  "sqls"
)

-- Diagnostic baseline. Signs in the gutter; no inline noise. Use <leader>e
-- (defined in lua/keymaps.lua) to read the full message in a floating window.
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅙",
      [vim.diagnostic.severity.WARN] = "󰀪",
      [vim.diagnostic.severity.HINT] = "󰌵",
      [vim.diagnostic.severity.INFO] = "󰋼",
    },
  },
  virtual_text = false,
  virtual_lines = false,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

-- Global LSP defaults: every server inherits these unless its config
-- overrides them.
vim.lsp.config("*", {
  capabilities = blink.capabilities,
  root_markers = { ".git" },
})

-- List of servers to enable. Each language stage appends to this list.
local servers = {}

---@param ... string server names that match a file at <config>/lsp/<name>.lua
local function enable(...)
  for _, name in ipairs({ ... }) do
    table.insert(servers, name)
  end
  vim.lsp.enable(servers)
end

-- Global keymap to format the current buffer manually.
vim.keymap.set("n", "<leader>af", function()
  format.format(0)
end, { desc = "Format buffer via priority resolver" })

-- Shared group for buffer-local document-highlight autocmds (cleared per buffer
-- on attach so a second client attaching doesn't stack duplicates).
local doc_highlight_group =
  vim.api.nvim_create_augroup("nightly-lsp-doc-highlight", { clear = true })

-- Track which client ids we've already announced, so the "ready" notification
-- below fires once per server instance (LspAttach fires per attached buffer).
local announced_ready = {}

-- LspAttach: keymaps + completion + format-on-save wiring.
-- grn/gra/grr/gri/grt/K/<C-s> are Neovim 0.11+ LSP defaults, so we don't
-- re-map them; only `grd` (definition) needs a dedicated binding.
vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP per-buffer setup",
  group = vim.api.nvim_create_augroup("nightly-lsp-attach", { clear = true }),
  callback = function(event)
    local bufnr = event.buf
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    -- Announce readiness once per client. LspAttach only fires after the server
    -- finishes `initialize`, so this marks the point the server is actually
    -- usable. This matters most for sqls: its `initialize` blocks on connecting
    -- to the database and introspecting the whole schema (see lua/packages/
    -- dbout.lua), which can take several seconds for a remote DB — completion and
    -- formatting do nothing until this fires.
    if not announced_ready[client.id] then
      announced_ready[client.id] = true
      vim.notify(("LSP ready: %s"):format(client.name), vim.log.levels.INFO)
    end

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "grd", vim.lsp.buf.definition, "LSP definition")

    -- vtsls / ts_ls specific: skip re-export hops to the real source. The base
    -- `gri` (vim.lsp.buf.implementation) is overwritten for vtsls buffers on
    -- purpose — implementation is rarely useful when the type system resolves it.
    if client.name == "vtsls" then
      map("n", "gri", function()
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
        client:request("workspace/executeCommand", {
          command = "typescript.goToSourceDefinition",
          arguments = { vim.uri_from_bufnr(0), params.position },
        }, function(err, result)
          if err then
            vim.notify("Go to Source: " .. tostring(err.message), vim.log.levels.ERROR)
            return
          end
          if result and #result > 0 then
            local loc = result[1]
            vim.lsp.util.show_document(
              { uri = loc.targetUri or loc.uri, range = loc.targetRange or loc.range },
              client.offset_encoding or "utf-16",
              { focus = true }
            )
          else
            vim.notify("No source definition found", vim.log.levels.INFO)
          end
        end, bufnr)
      end, "TS: Go to Source Definition")
    end

    -- Inlay hints: off by default to keep the buffer quiet; <leader>th toggles
    -- them per-buffer. is_enabled() returns false when never enabled, so the
    -- first press turns them on.
    if client:supports_method("textDocument/inlayHint") then
      map("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(
          not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
          { bufnr = bufnr }
        )
      end, "Toggle inlay hints")
    end

    -- CodeLens (the "N references" / "N implementations" annotations above
    -- symbols): off by default to keep the buffer quiet. <leader>tl toggles the
    -- display per-buffer via the declarative capability (Neovim 0.13+), which
    -- owns its own refresh — re-requesting on buffer changes (debounced) once
    -- enabled. <leader>cl runs the lens under the cursor.
    if client:supports_method("textDocument/codeLens") then
      map("n", "<leader>tl", function()
        vim.lsp.codelens.enable(
          not vim.lsp.codelens.is_enabled({ bufnr = bufnr }),
          { bufnr = bufnr }
        )
      end, "Toggle CodeLens")
      map("n", "<leader>cl", vim.lsp.codelens.run, "Run CodeLens")
    end

    -- Document highlight: underline other references of the symbol under the
    -- cursor on hold, clear on move. Buffer-local, only when supported.
    if client:supports_method("textDocument/documentHighlight") then
      vim.api.nvim_clear_autocmds({ group = doc_highlight_group, buffer = bufnr })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = doc_highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = doc_highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end

    -- Preserve our global formatoptions; some servers re-set this on attach.
    vim.bo[bufnr].formatoptions = vim.go.formatoptions
  end,
})

-- Format-on-save toggle. :FormatDisable[!] turns it off globally (or with !
-- for the current buffer only); :FormatEnable turns it back on.
vim.api.nvim_create_user_command("FormatDisable", function(opts)
  if opts.bang then
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, { bang = true, desc = "Disable format-on-save (! = current buffer only)" })

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, { desc = "Re-enable format-on-save" })

-- Fresh-machine self-heal. mason-tool-installer installs binaries asynchronously
-- (start_delay 2000ms), but enable() below runs at startup — so on a new box the
-- server `cmd`s don't exist on PATH yet and vim.lsp.enable's attach attempts no-op.
-- When the installer finishes having actually installed something (ev.data lists the
-- newly-installed packages; it's empty on a normal startup where everything is
-- already present), re-fire FileType on loaded file buffers so vim.lsp.enable's
-- matchers attach now that the binaries are on disk. vim.lsp.start dedupes by
-- name+root, so this never double-attaches; treesitter's FileType handler is
-- idempotent too. Mirrors how treesitter/fzf-native already self-bootstrap.
vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  desc = "Attach LSP to open buffers once newly-installed binaries land",
  group = vim.api.nvim_create_augroup("nightly-lsp-mason-selfheal", { clear = true }),
  callback = function(ev)
    if vim.tbl_isempty(ev.data or {}) then
      return -- nothing newly installed; servers already attached normally
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
        vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
      end
    end
  end,
})

-- Format on save. The priority resolver decides which client wins per buffer.
-- Honors the vim.g / vim.b disable_autoformat escape hatch.
vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Format buffer before save",
  group = vim.api.nvim_create_augroup("nightly-lsp-format-on-save", { clear = true }),
  callback = function(args)
    if
      vim.g.disable_autoformat
      or vim.b[args.buf].disable_autoformat
      or vim.b[args.buf].large_buf
    then
      return
    end
    format.format(args.buf)
  end,
})

-- Lua
format.register("stylua", 100)
enable("lua_ls", "stylua", "efm")

-- Bash. efm already enabled above; register it for bash priority.
-- (stylua's filetype is lua-only, so the lower priority here is purely defensive.)
format.register("efm", 90)
enable("bashls")

-- TypeScript LSP only (formatting/linting in later stages)
enable("vtsls")

-- TypeScript formatting. The JS/TS format-on-save pipeline lives in
-- lua/lsp/ts_format.lua (driven from lsp/format.lua); no formatter is registered
-- in the generic resolver. oxlint/eslint attach per project only to supply their
-- source.fixAll code actions to that pipeline.
enable("oxlint", "eslint")

-- TypeScript linting. eslint/oxlint (enabled above) already emit inline
-- diagnostics once attached; their configs add fix-all commands. biome only ran
-- as a CLI formatter of format-on-save, so we attach its LSP here for lint diagnostics.
-- No formatter is registered — format-on-save's pipeline owns JS/TS formatting.
enable("biome")

-- Markup (markdown/json/html/css/yaml/xml). marksman/jsonls/html/cssls/
-- yamlls provide LSP features; efm (prettier, registered above) formats them and
-- lints markdown via markdownlint. lemminx is the only XML formatter, so it's
-- registered.
format.register("lemminx", 100)
enable("marksman", "jsonls", "html", "cssls", "yamlls", "lemminx")

-- Python. basedpyright provides language intelligence with its own
-- formatting disabled (see lsp/basedpyright.lua); ruff owns lint + format +
-- organize-imports. ruff is Python's only formatter, registered at the same
-- priority as the other single-language formatters.
format.register("ruff", 100)
enable("basedpyright", "ruff")

-- Hledger. hledger-lsp is opt-in and not in Mason; native vim.lsp
-- silently skips a server whose cmd isn't executable, so this is a no-op when
-- the binary isn't on PATH (no client, no error). See lsp/hledger.lua.
enable("hledger")
