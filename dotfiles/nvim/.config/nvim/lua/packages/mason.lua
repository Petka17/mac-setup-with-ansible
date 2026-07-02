vim.pack.add({
  { src = "https://github.com/mason-org/mason.nvim" },
  { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
})

require("mason").setup({
  ui = { border = "rounded" },
})

-- Single source of truth for every binary we want auto-installed.
-- Each language stage appends its tools here via the helper below.
local tools = {}

local function apply()
  require("mason-tool-installer").setup({
    ensure_installed = tools,
    auto_update = false,
    run_on_start = true,
    start_delay = 2000,
  })
end

-- Exported helper so each language plan can register its tools by appending to
-- the list. Multiple ensure() calls in the same tick collapse into a single
-- mason-tool-installer.setup() via vim.schedule, so we don't re-run setup once
-- per language stage.
local M = {}

local scheduled = false

function M.ensure(...)
  for _, name in ipairs({ ... }) do
    table.insert(tools, name)
  end
  if not scheduled then
    scheduled = true
    vim.schedule(function()
      scheduled = false
      apply()
    end)
  end
end

return M
