local M = {}

local review_files = require("localreview.review_files")

---@param target { target_path: string, kind: string }
---@return boolean
local function current_buffer_is_affected(target)
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" then
    return false
  end

  local absolute_bufpath = vim.fn.fnamemodify(bufpath, ":p")

  if target.kind == "file" then
    return absolute_bufpath == target.target_path
  end

  if target.kind == "review_file" then
    local source_path = review_files.source_path_from_review_file(target.target_path)
    return source_path == absolute_bufpath
  end

  local prefix = target.target_path .. "/"
  return absolute_bufpath == target.target_path or absolute_bufpath:sub(1, #prefix) == prefix
end

---@param path string|nil
---@return number|nil, table|nil, string|nil
function M.clear_path(path)
  local target, err = review_files.collect_review_files(path)
  if not target then
    return nil, nil, err
  end

  local deleted = 0
  for _, review_file in ipairs(target.review_files) do
    if vim.fn.filereadable(review_file) == 1 and vim.fn.delete(review_file) == 0 then
      deleted = deleted + 1
    end
  end

  return deleted, target, nil
end

---@param path string|nil
function M.clear(path)
  local deleted, target, err = M.clear_path(path)
  if deleted == nil then
    vim.notify(err or "[localreview] Failed to clear review comments.", vim.log.levels.WARN)
    return
  end

  if deleted == 0 then
    vim.notify("[localreview] No review comments found for the selected path.", vim.log.levels.INFO)
    return
  end

  if current_buffer_is_affected(target) then
    vim.api.nvim_buf_clear_namespace(0, require("localreview.virtual_text").ns, 0, -1)
  end

  local suffix = deleted == 1 and "file" or "files"
  vim.notify(string.format("[localreview] Cleared review comments from %d %s", deleted, suffix), vim.log.levels.INFO)
end

return M
