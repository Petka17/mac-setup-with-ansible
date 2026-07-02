vim.pack.add({
  { src = "https://github.com/stevearc/oil.nvim" },
})

require("oil").setup({
  -- Replace netrw entirely. Opening a directory (`nvim somedir/`) lands in oil.
  default_file_explorer = true,

  delete_to_trash = false,
  skip_confirm_for_simple_edits = false,
  view_options = {
    show_hidden = true,
    natural_order = true,
    is_always_hidden = function(name)
      return name == ".DS_Store"
    end,
  },
  float = {
    padding = 4,
    max_width = 100,
    max_height = 30,
    border = "rounded",
  },
  -- Intentional divergence from the global `signcolumn = "yes"`: oil uses the
  -- sign column to display entry status icons (modified, new, deleted), so it
  -- needs the wider two-column variant while the buffer is open.
  win_options = {
    signcolumn = "yes:2",
  },
  -- Oil's defaults include <C-h>/<C-l>/<C-s>; those clash with our split-nav
  -- keymaps (lua/keymaps.lua). We replace the conflicting ones with safer
  -- bindings and leave the rest of oil's defaults intact.
  keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-v>"] = "actions.select_vsplit",
    ["<C-x>"] = "actions.select_split",
    ["<C-t>"] = "actions.select_tab",
    ["<C-p>"] = "actions.preview",
    ["q"] = "actions.close",
    ["<C-r>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil dir" },
    ["gs"] = "actions.change_sort",
    ["gx"] = "actions.open_external",
    ["g."] = "actions.toggle_hidden",
    ["g\\"] = "actions.toggle_trash",
  },
  -- Disable defaults we just remapped or that collide with split nav.
  use_default_keymaps = false,
})

-- Open oil in the parent of the current buffer (project convention).
vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Open parent dir in oil" })

-- Toggle floating oil
vim.keymap.set("n", "\\", function()
  require("oil").toggle_float()
end, { desc = "Toggle oil (floating)" })
