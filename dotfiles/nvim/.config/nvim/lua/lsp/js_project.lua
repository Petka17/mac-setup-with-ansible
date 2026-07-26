-- Shared JS/TS project-root helpers for vtsls and eslint. Keeps Deno exclusion
-- and npm-root detection in one place so both servers stay aligned.
local M = {}

M.package_manager_lockfiles = {
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lockb",
  "bun.lock",
}

M.deno_markers = { "deno.json", "deno.jsonc", "deno.lock" }

--- True when the buffer is in a pure or nested Deno project (skip vtsls/eslint).
--- Hybrid repos (lockfile + deno.json at the same root) return false so npm
--- tooling still attaches. Longer path == deeper == closer to the buffer.
---@param bufnr integer
---@return boolean
function M.is_deno_project(bufnr)
  local lockfile_root = vim.fs.root(bufnr, M.package_manager_lockfiles)
  local deno_root = vim.fs.root(bufnr, M.deno_markers)
  return deno_root ~= nil and (lockfile_root == nil or #deno_root > #lockfile_root)
end

--- Nearest npm/pnpm/yarn/bun project root, or nil. Requires a lockfile,
--- package.json, or .git — no getcwd() fallback, so scratch files outside a
--- project do not spawn vtsls.
---@param bufnr integer
---@return string|nil
function M.npm_project_root(bufnr)
  return vim.fs.root(bufnr, M.package_manager_lockfiles)
    or vim.fs.root(bufnr, { "package.json" })
    or vim.fs.root(bufnr, { ".git" })
end

--- Path to a TS7 + @effect/tsgo project's native `tsc` launcher, or nil.
--- Presence of node_modules/.bin/effect-tsgo marks the project as effect-tsgo-
--- managed (TypeScript 7 native compiler with the Effect Language Service patched
--- in). That patched launcher doubles as the LSP server (`tsc --lsp --stdio`), so
--- projects on this toolchain use it instead of vtsls (which wraps the classic
--- tsserver TS7 no longer ships).
---
--- The native compiler may sit at plain `typescript` (the usual layout: `typescript`
--- is TS7) or under a `@typescript/native` alias (used when a project must keep a
--- second TS at 6.x for tooling that needs the removed JS API). Try both.
---@param root string|nil npm project root
---@return string|nil launcher absolute path when this is an effect-tsgo project
function M.effect_tsgo_launcher(root)
  if not root then
    return nil
  end
  local marker = vim.fs.joinpath(root, "node_modules", ".bin", "effect-tsgo")
  if vim.uv.fs_stat(marker) == nil then
    return nil
  end
  local candidates = {
    vim.fs.joinpath(root, "node_modules", "typescript", "bin", "tsc"),
    vim.fs.joinpath(root, "node_modules", "@typescript", "native", "bin", "tsc"),
  }
  for _, launcher in ipairs(candidates) do
    if vim.fn.executable(launcher) == 1 then
      return launcher
    end
  end
  return nil
end

--- True when the buffer's project is managed by @effect/tsgo. Used to route:
--- the effect_tsgo server attaches, vtsls stays away so they don't both spawn.
--- Deno projects are excluded (they never use npm TS tooling).
---@param bufnr integer
---@return boolean
function M.is_effect_tsgo_project(bufnr)
  if M.is_deno_project(bufnr) then
    return false
  end
  return M.effect_tsgo_launcher(M.npm_project_root(bufnr)) ~= nil
end

return M
