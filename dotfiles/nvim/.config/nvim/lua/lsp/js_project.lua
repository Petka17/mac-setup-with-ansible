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

return M
