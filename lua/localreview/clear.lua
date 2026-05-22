local M = {}

local review_files = require("localreview.review_files")
local storage = require("localreview.storage")
local session = require("localreview.session")

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

local function count_entries(data)
  local count = 0
  if not data or not data.reviews then
    return count
  end

  for _, reviews in pairs(data.reviews) do
    count = count + #reviews
  end

  return count
end

local function clear_review_file(review_file, active_session_name)
  local data = storage.read_reviews(review_file)
  if not data or not data.reviews then
    return 0
  end

  if not active_session_name then
    local total = count_entries(data)
    if total > 0 and vim.fn.delete(review_file) == 0 then
      return total
    end
    return 0
  end

  local removed = 0
  local kept_reviews = {}

  for line_key, reviews in pairs(data.reviews) do
    local kept = {}
    for _, entry in ipairs(reviews) do
      if entry.session_name == active_session_name then
        removed = removed + 1
      else
        kept[#kept + 1] = entry
      end
    end

    if #kept > 0 then
      kept_reviews[line_key] = kept
    end
  end

  if removed == 0 then
    return 0
  end

  if next(kept_reviews) == nil then
    vim.fn.delete(review_file)
  else
    storage.write_reviews(review_file, { reviews = kept_reviews })
  end

  return removed
end

---@param path string|nil
---@param opts? { include_all_sessions?: boolean }
---@return number|nil, table|nil, string|nil
function M.clear_path(path, opts)
  opts = opts or {}

  local target, err = review_files.collect_review_files(path)
  if not target then
    return nil, nil, err
  end

  local active_session_name = nil
  if not opts.include_all_sessions then
    active_session_name = session.name()
  end

  local deleted = 0
  for _, review_file in ipairs(target.review_files) do
    deleted = deleted + clear_review_file(review_file, active_session_name)
  end

  return deleted, target, nil
end

---@param path string|nil
---@param opts? { include_all_sessions?: boolean }
function M.clear(path, opts)
  opts = opts or {}

  local deleted, target, err = M.clear_path(path, opts)
  if deleted == nil then
    vim.notify(err or "[localreview] Failed to clear review comments.", vim.log.levels.WARN)
    return
  end

  if deleted == 0 then
    vim.notify("[localreview] No review comments found for the selected path.", vim.log.levels.INFO)
    return
  end

  if current_buffer_is_affected(target) then
    require("localreview.virtual_text").refresh_line(0, vim.api.nvim_win_get_cursor(0)[1])
    vim.api.nvim_buf_clear_namespace(0, require("localreview.virtual_text").ns, 0, -1)
    local bufpath = vim.api.nvim_buf_get_name(0)
    local data = storage.read_reviews(storage.review_path(bufpath))
    require("localreview.virtual_text").render_all(0, data)
  end

  local message = string.format("[localreview] Cleared %d review comment%s", deleted, deleted == 1 and "" or "s")
  if not opts.include_all_sessions and session.name() then
    message = message .. " from session `" .. session.name() .. "`"
  end
  vim.notify(message, vim.log.levels.INFO)
end

return M
