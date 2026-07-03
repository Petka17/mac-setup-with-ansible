vim.pack.add({
  { src = "https://github.com/NeogitOrg/neogit" },
  { src = "https://github.com/sindrets/diffview.nvim" },
})

-- macOS: silence MallocStackLogging spam from spawned git children.
vim.env.MallocStackLogging = nil
vim.env.MallocStackLoggingNoCompact = nil

require("neogit").setup({
  integrations = {
    diffview = true,
    fzf_lua = true, -- reuse the picker already installed in packages/fzf.lua
  },
  graph_style = "unicode",
  signs = {
    section = { "", "" },
    item = { "", "" },
    hunk = { "", "" },
  },
})

vim.keymap.set("n", "<leader>g", function()
  require("neogit").open()
end, { desc = "Open Neogit status" })

-- Conflict resolution: Neogit hands the merge UI to diffview when a conflict
-- is detected. The three-way merge layout opens automatically; in it:
--   - <leader>co — choose OURS for current hunk
--   - <leader>ct — choose THEIRS
--   - <leader>cb — choose BOTH
--   - <leader>c0 — choose NEITHER
-- These are diffview defaults; reproduced here for discoverability.
vim.keymap.set("n", "<leader>gm", function()
  vim.cmd("DiffviewOpen")
end, { desc = "Open diffview (full repo diff / merge view)" })

vim.keymap.set("n", "<leader>gh", function()
  vim.cmd("DiffviewFileHistory %")
end, { desc = "File history (current file)" })
