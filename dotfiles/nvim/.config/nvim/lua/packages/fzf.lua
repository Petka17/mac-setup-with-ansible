-- fzf-lua: fuzzy finder. Uses the fzf/fd/rg/bat binaries (installed via the ansible
-- terminal.yml), so there is no build step and no plenary dependency (unlike telescope).

vim.pack.add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
})

local fzf = require("fzf-lua")
local fzf_actions = require("fzf-lua.actions")

fzf.setup({
  winopts = {
    -- Mirror the old telescope layout: preview on the right at 55% width.
    preview = { layout = "horizontal", horizontal = "right:55%" },
  },
  keymap = {
    fzf = {
      -- Replicate telescope's <ctrl-q>: send the whole (filtered) result list to
      -- the quickfix list. `select-all` marks every entry matching the current
      -- query, then `accept` fires the picker's default action (file_edit_or_qf),
      -- which routes a multi-selection into quickfix instead of opening one file.
      -- Merges with fzf-lua's default fzf keymaps rather than replacing them.
      ["ctrl-q"] = "select-all+accept",
    },
  },
  grep = {
    actions = {
      -- <ctrl-g> (the default live<->fuzzy toggle) is shadowed by wezterm, so move
      -- it to <ctrl-q>. The picker's "to Fuzzy Search" header updates automatically.
      ["ctrl-g"] = false,
      ["ctrl-v"] = { fzf_actions.grep_lgrep },
    },
  },
})

-- General
vim.keymap.set("n", "<leader>sh", fzf.helptags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sc", fzf.commands, { desc = "[S]earch [C]ommands" })
vim.keymap.set("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>sd", fzf.diagnostics_workspace, { desc = "[S]earch [D]iagnostics" })

-- Files & buffers
vim.keymap.set("n", "<leader>sf", function()
  -- --hidden so dotfiles are searchable; exclude .git to match the old config.
  fzf.files({ cmd = "rg --files --hidden --glob '!**/.git/*'" })
end, { desc = "[S]earch [F]iles" })

vim.keymap.set("n", "<leader>s.", fzf.oldfiles, { desc = "[S]earch recent files" })
vim.keymap.set("n", "<leader>sb", fzf.buffers, { desc = "[S]earch [B]uffers" })

-- Content
vim.keymap.set("n", "<leader>sw", fzf.grep_cword, { desc = "[S]earch current [W]ord" })

vim.keymap.set("n", "<leader>sg", function()
  fzf.live_grep({
    rg_opts = "--hidden --glob '!**/.git/*' --column --line-number --no-heading "
      .. "--color=always --smart-case --max-columns=4096",
  })
end, { desc = "[S]earch by [G]rep" })

-- Fuzzy search across lines of all open buffers (closest analogue to telescope's
-- live_grep with grep_open_files).
vim.keymap.set("n", "<leader>s/", fzf.lines, { desc = "[S]earch [/] in open files" })

-- LSP-aware searches
vim.keymap.set(
  "n",
  "<leader>ss",
  fzf.lsp_document_symbols,
  { desc = "[S]earch document [S]ymbols" }
)
vim.keymap.set(
  "n",
  "<leader>sS",
  fzf.lsp_live_workspace_symbols,
  { desc = "[S]earch workspace [S]ymbols" }
)
