local M = {}

---@private
---@param start_line number 1-indexed start line
---@param end_line number|nil 1-indexed end line for range reviews
local function do_annotate(start_line, end_line)
  local storage = require("localreview.storage")
  local bufpath = storage.get_buf_filepath()
  if not bufpath then
    return
  end

  local session_name = require("localreview.session").name()
  if not session_name then
    vim.notify("[localreview] Start review mode first with :LocalReviewStart [name]", vim.log.levels.WARN)
    return
  end

  local line_key = tostring(start_line)
  local review_file = storage.review_path(bufpath)

  local prompt = "Review: "
  if end_line and end_line ~= start_line then
    prompt = "Review (L" .. start_line .. "-" .. end_line .. "): "
  end

  vim.ui.input({ prompt = prompt }, function(comment)
    if not comment or comment == "" then
      return
    end

    local data = storage.read_reviews(review_file) or { reviews = {} }
    if not data.reviews[line_key] then
      data.reviews[line_key] = {}
    end

    local commit = nil
    local cfg = require("localreview.config").values
    if cfg.git.track_commit then
      commit = require("localreview.git").get_head_sha(bufpath)
    end

    local range_end = (end_line and end_line ~= start_line) and end_line or nil
    local entry = storage.new_review_entry(comment, range_end, commit, session_name)
    table.insert(data.reviews[line_key], entry)
    storage.write_reviews(review_file, data)

    require("localreview.virtual_text").refresh_line(0, start_line)
  end)
end

---@return nil
function M.annotate()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    do_annotate(start_line, end_line)
  else
    local line = vim.api.nvim_win_get_cursor(0)[1]
    do_annotate(line, nil)
  end
end

---@param line1 number start line (1-indexed)
---@param line2 number end line (1-indexed)
function M.annotate_range_from_lines(line1, line2)
  if line1 > line2 then
    line1, line2 = line2, line1
  end
  do_annotate(line1, line2)
end

---@private
---@param data table review data
---@param line number 1-indexed cursor line
---@return table[] matches list of {line_key, idx, entry} tables
local function find_reviews_at(data, line)
  local matches = {}
  local line_key = tostring(line)

  if data.reviews[line_key] then
    for idx, entry in ipairs(data.reviews[line_key]) do
      matches[#matches + 1] = { line_key = line_key, idx = idx, entry = entry }
    end
  end

  for key, reviews in pairs(data.reviews) do
    local start = tonumber(key)
    if start and key ~= line_key then
      for idx, entry in ipairs(reviews) do
        if entry.end_line and line >= start and line <= entry.end_line then
          matches[#matches + 1] = { line_key = key, idx = idx, entry = entry }
        end
      end
    end
  end

  return matches
end

---@return nil
function M.delete_review()
  local storage = require("localreview.storage")
  local bufpath = storage.get_buf_filepath()
  if not bufpath then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local review_file = storage.review_path(bufpath)
  local data = storage.read_reviews(review_file)

  if not data or not data.reviews then
    vim.notify("[localreview] No reviews on this line", vim.log.levels.WARN)
    return
  end

  local matches = find_reviews_at(data, line)

  if #matches == 0 then
    vim.notify("[localreview] No reviews on this line", vim.log.levels.WARN)
    return
  end

  local function do_delete(match)
    local reviews = data.reviews[match.line_key]
    for i, entry in ipairs(reviews) do
      if entry == match.entry then
        table.remove(reviews, i)
        break
      end
    end
    if #reviews == 0 then
      data.reviews[match.line_key] = nil
    end
    storage.write_reviews(review_file, data)
    require("localreview.virtual_text").refresh_line(0, tonumber(match.line_key))
  end

  if #matches == 1 then
    do_delete(matches[1])
    return
  end

  vim.ui.select(matches, {
    prompt = "Delete review:",
    format_item = function(match)
      local ago = require("localreview.display")._relative_time(match.entry.timestamp)
      local preview = match.entry.comment:sub(1, 50)
      if #match.entry.comment > 50 then
        preview = preview .. "..."
      end
      return preview .. " (" .. ago .. ")"
    end,
  }, function(choice)
    if not choice then
      return
    end
    do_delete(choice)
  end)
end

return M
