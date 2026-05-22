local M = {}

local function resolve_git_dir(path)
  if not path or path == "" then
    return vim.fn.getcwd()
  end

  if vim.fn.isdirectory(path) == 1 then
    return path
  end

  return vim.fn.fnamemodify(path, ":h")
end

---@param filepath string absolute path to any file or directory in the repo
---@return string|nil SHA (40-char hex) or nil if not in a git repo
function M.get_head_sha(filepath)
  local dir = resolve_git_dir(filepath)
  local result = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " rev-parse HEAD")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

---@param filepath string absolute path to any file or directory in the repo
---@return string|nil git root directory or nil
function M.get_git_root(filepath)
  local dir = resolve_git_dir(filepath)
  local result = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

---@param review_sha string|nil commit SHA stored on review
---@param current_sha string|nil current HEAD SHA
---@return boolean true if review is stale
function M.is_stale(review_sha, current_sha)
  if not review_sha or not current_sha then
    return false
  end
  return review_sha ~= current_sha
end

return M
