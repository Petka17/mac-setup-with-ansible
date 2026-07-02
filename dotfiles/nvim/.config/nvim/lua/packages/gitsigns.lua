vim.pack.add({
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
})

local gitsigns = require("gitsigns")

gitsigns.setup({
  signs = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "▁" },
    topdelete = { text = "▔" },
    changedelete = { text = "▎" },
    untracked = { text = "▎" },
  },
  signs_staged_enable = true,
  current_line_blame = false, -- toggleable via <leader>gb
  current_line_blame_opts = { virt_text_pos = "eol", delay = 500 },
  on_attach = function(bufnr)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- Hunk navigation
    map("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gitsigns.nav_hunk("next")
      end
    end, "Next git hunk")

    map("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gitsigns.nav_hunk("prev")
      end
    end, "Prev git hunk")

    -- Hunk actions
    map("n", "<leader>hs", gitsigns.stage_hunk, "Stage hunk")
    map("n", "<leader>hr", gitsigns.reset_hunk, "Reset hunk")
    map("v", "<leader>hs", function()
      gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage hunk (visual)")
    map("v", "<leader>hr", function()
      gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Reset hunk (visual)")
    map("n", "<leader>hS", gitsigns.stage_buffer, "Stage buffer")
    map("n", "<leader>hR", gitsigns.reset_buffer, "Reset buffer")
    map("n", "<leader>hp", gitsigns.preview_hunk, "Preview hunk")
    map("n", "<leader>hi", gitsigns.preview_hunk_inline, "Preview hunk inline")
    map("n", "<leader>hd", gitsigns.toggle_deleted, "Toggle deleted lines")

    -- Blame
    map("n", "<leader>hb", function()
      gitsigns.blame_line({ full = true })
    end, "Blame line (full)")
    map("n", "<leader>gb", gitsigns.toggle_current_line_blame, "Toggle line blame")
  end,
})
