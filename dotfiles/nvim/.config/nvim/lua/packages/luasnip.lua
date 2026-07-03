vim.pack.add({
  { src = "https://github.com/L3MON4D3/LuaSnip" },
})

require("luasnip.loaders.from_lua").load()

local ls = require("luasnip")

vim.keymap.set({ "i", "s" }, "<C-e>", function()
  ls.expand()
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-J>", function()
  ls.jump(1)
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-K>", function()
  ls.jump(-1)
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-L>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, { silent = true })
