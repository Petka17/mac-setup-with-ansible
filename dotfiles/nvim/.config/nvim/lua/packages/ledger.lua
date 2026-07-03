-- Hledger editor ergonomics via vim-ledger.
--
-- Syntax highlighting comes from the `ledger` treesitter parser (installed in
-- packages/treesitter.lua and aliased to the `hledger` filetype there). This
-- module only pulls in vim-ledger for its editor commands (:LedgerAlign,
-- :Balance, :Reconcile, ...) and its buffer-local options (commentstring,
-- folds, formatexpr).

vim.pack.add({
  { src = "https://github.com/ledger/vim-ledger" },
})

-- vim-ledger ships an ftdetect for *.ledger and an ftplugin keyed on the
-- `ledger` filetype. Our *.journal files are mapped to `hledger` (see
-- packages/treesitter.lua) so that ftplugin never runs for them. Bridge it by
-- sourcing the ledger ftplugin *in place* on hledger buffers.
--
-- We deliberately do NOT swap the buffer's filetype to `ledger` and back:
-- changing the filetype away from `ledger` would trigger `b:undo_ftplugin`,
-- undoing exactly the settings we want, and re-setting `hledger` would re-fire
-- this same autocmd in a loop. `runtime! ftplugin/ledger.vim` applies the
-- ledger ftplugin to the current (hledger) buffer without touching 'filetype',
-- and vim-ledger's own `b:did_ftplugin` guard makes a second firing a no-op.
local ledger_group = vim.api.nvim_create_augroup("nightly-ledger-ftplugin", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "hledger",
  desc = "Apply the vim-ledger ftplugin to hledger buffers",
  group = ledger_group,
  callback = function()
    vim.cmd("runtime! ftplugin/ledger.vim")
  end,
})

-- ---------------------------------------------------------------------------
-- Journal formatting (pure Lua, non-lossy): sort transactions by date and
-- collapse excess blank lines. See the on-save autocmd below.
-- ---------------------------------------------------------------------------

-- Extract a sortable YYYY-MM-DD key from a transaction header line, or nil if
-- the line does not start with a full (4-digit-year) date at column 0. Postings
-- are indented so they never match; price/periodic/directive lines start with a
-- non-digit so they never match either.
local function txn_date(line)
  local y, mo, d = line:match("^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)")
  if not y then
    return nil
  end
  return string.format("%04d-%02d-%02d", tonumber(y), tonumber(mo), tonumber(d))
end

-- Split buffer lines into ordered chunks: "txn" (date header + indented
-- postings), "directive" (anything else at column 0 + its indented body,
-- including `comment`/`end comment` blocks), and "blank" (a run of blank lines).
local function parse_chunks(lines)
  local chunks, i, n = {}, 1, #lines
  while i <= n do
    local line = lines[i]
    if line:match("^%s*$") then
      local chunk = { type = "blank", lines = {} }
      while i <= n and lines[i]:match("^%s*$") do
        chunk.lines[#chunk.lines + 1] = lines[i]
        i = i + 1
      end
      chunks[#chunks + 1] = chunk
    elseif line:match("^comment%s*$") or line:match("^comment%s") then
      -- Multi-line comment block: swallow through `end comment` so a date-like
      -- line inside it is never treated as a transaction.
      local chunk = { type = "directive", lines = { line } }
      i = i + 1
      while i <= n do
        chunk.lines[#chunk.lines + 1] = lines[i]
        local stop = lines[i]:match("^end%s+comment")
        i = i + 1
        if stop then
          break
        end
      end
      chunks[#chunks + 1] = chunk
    else
      local date = txn_date(line)
      local chunk = { type = date and "txn" or "directive", lines = { line }, date = date }
      i = i + 1
      -- Consume indented continuation lines (postings, inline comments).
      while i <= n and lines[i]:match("^%s") and not lines[i]:match("^%s*$") do
        chunk.lines[#chunk.lines + 1] = lines[i]
        i = i + 1
      end
      chunks[#chunks + 1] = chunk
    end
  end
  return chunks
end

-- Stable-sort transactions by date within each maximal run of non-directive
-- chunks. Transactions are only permuted among their own slots — blank chunks
-- and directives keep their positions, so nothing crosses a directive or a
-- free-standing comment barrier.
local function sort_transactions(chunks)
  local i, n = 1, #chunks
  while i <= n do
    if chunks[i].type == "directive" then
      i = i + 1
    else
      local slots, txns = {}, {}
      while i <= n and chunks[i].type ~= "directive" do
        if chunks[i].type == "txn" then
          slots[#slots + 1] = i
          txns[#txns + 1] = { chunk = chunks[i], order = #txns + 1 }
        end
        i = i + 1
      end
      table.sort(txns, function(a, b)
        if a.chunk.date == b.chunk.date then
          return a.order < b.order -- stable: keep original order for equal dates
        end
        return a.chunk.date < b.chunk.date
      end)
      for k, slot in ipairs(slots) do
        chunks[slot] = txns[k].chunk
      end
    end
  end
end

-- Collapse runs of 2+ blank lines to one and strip leading/trailing blanks.
local function collapse_blanks(lines)
  local out, prev_blank = {}, false
  for _, l in ipairs(lines) do
    if l:match("^%s*$") then
      if not prev_blank and #out > 0 then
        out[#out + 1] = ""
      end
      prev_blank = true
    else
      out[#out + 1] = l
      prev_blank = false
    end
  end
  while #out > 0 and out[#out]:match("^%s*$") do
    out[#out] = nil
  end
  return out
end

local function lines_equal(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

-- Reorder transactions by date and collapse excess blank lines. Writes back
-- only when something actually changed (keeps 'modified'/undo history quiet).
local function format_journal(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local chunks = parse_chunks(lines)
  sort_transactions(chunks)
  local flat = {}
  for _, chunk in ipairs(chunks) do
    for _, l in ipairs(chunk.lines) do
      flat[#flat + 1] = l
    end
  end
  local result = collapse_blanks(flat)
  if not lines_equal(lines, result) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, result)
  end
end

-- On save: sort transactions by date, collapse excess blanks, then align
-- commodities (vim-ledger's :LedgerAlignBuffer). Buffer-local so it only touches
-- ledger/hledger files. Honors the same escape hatch as the LSP format-on-save
-- pipeline in lua/lsp/init.lua — :FormatDisable[!] turns it off too — and
-- preserves the cursor/view since these rewrites shift lines and columns.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "hledger", "ledger" },
  desc = "Wire ledger sort + align into format-on-save",
  group = ledger_group,
  callback = function(args)
    if vim.fn.exists(":LedgerAlignBuffer") ~= 2 then
      return -- ftplugin didn't load; nothing to align with
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = args.buf,
      desc = "Sort + align ledger transactions before save",
      group = ledger_group,
      callback = function(ev)
        if
          vim.g.disable_autoformat
          or vim.b[ev.buf].disable_autoformat
          or vim.b[ev.buf].large_buf
        then
          return
        end
        local view = vim.fn.winsaveview()
        format_journal(ev.buf)
        vim.cmd("LedgerAlignBuffer")
        vim.fn.winrestview(view)
      end,
    })
  end,
})

-- vim-ledger settings (read globally by the plugin).
vim.g.ledger_default_commodity = "EUR" -- change if your base currency differs
vim.g.ledger_decimal_sep = "."
vim.g.ledger_align_at = 60
-- vim.g.ledger_align_commodity = 1
vim.g.ledger_main = "main.journal"
