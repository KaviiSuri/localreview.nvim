local M = {}

---@param bufpath string absolute path to the source file
---@return string review file path (hidden JSON file in same directory)
function M.review_path(bufpath)
  local dir = vim.fn.fnamemodify(bufpath, ":h")
  local name = vim.fn.fnamemodify(bufpath, ":t")
  return dir .. "/." .. name .. ".reviews.json"
end

---@param comment string review comment text
---@param end_line number|nil end line for range reviews
---@param commit string|nil git HEAD SHA at time of creation
---@param session_name string|nil active review session name
---@return table review entry with comment, timestamp, end_line, commit, session_name
function M.new_review_entry(comment, end_line, commit, session_name)
  return {
    comment = comment,
    timestamp = os.time(),
    end_line = end_line or vim.NIL,
    commit = commit or vim.NIL,
    session_name = session_name or vim.NIL,
  }
end

---@param filepath string path to the review JSON file
---@param data table review data (will have version=1 set)
---@return boolean success
function M.write_reviews(filepath, data)
  data.version = 1

  local json = vim.json.encode(data)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  local tmp = dir .. "/.localreview_tmp_" .. vim.fn.getpid()

  local write_ok = vim.fn.writefile({ json }, tmp)
  if write_ok ~= 0 then
    vim.notify("[localreview] Failed to write temp file: " .. tmp, vim.log.levels.ERROR)
    vim.fn.delete(tmp)
    return false
  end

  local rename_ok = vim.fn.rename(tmp, filepath)
  if rename_ok ~= 0 then
    vim.notify("[localreview] Failed to rename temp file", vim.log.levels.ERROR)
    vim.fn.delete(tmp)
    return false
  end

  return true
end

---@param filepath string path to the review JSON file
---@return table|nil review data, or nil on missing/corrupt/empty file
function M.read_reviews(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end

  local lines = vim.fn.readfile(filepath)
  local content = table.concat(lines, "\n")

  if content:match("^%s*$") then
    return nil
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("[localreview] Corrupted review file: " .. filepath, vim.log.levels.WARN)
    return nil
  end

  if data and data.reviews then
    for _, reviews in pairs(data.reviews) do
      for _, entry in ipairs(reviews) do
        if entry.end_line == vim.NIL then
          entry.end_line = nil
        end
        if entry.commit == vim.NIL then
          entry.commit = nil
        end
        if entry.session_name == vim.NIL then
          entry.session_name = nil
        end
      end
    end
  end

  return data
end

---@return string|nil buffer file path, or nil for non-file buffers
function M.get_buf_filepath()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" or vim.bo.buftype ~= "" then
    vim.notify("[localreview] Not a file buffer", vim.log.levels.WARN)
    return nil
  end
  return bufpath
end

return M
