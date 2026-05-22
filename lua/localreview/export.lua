local M = {}

local review_files = require("localreview.review_files")
local storage = require("localreview.storage")
local git = require("localreview.git")

local function split_lines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function read_code_excerpt(source_path, start_line, end_line)
  if vim.fn.filereadable(source_path) ~= 1 then
    return nil
  end

  local lines = vim.fn.readfile(source_path)
  if #lines == 0 then
    return nil
  end

  local first = math.max(start_line, 1)
  local last = math.min(end_line or start_line, #lines)
  local excerpt = {}

  for line_nr = first, last do
    excerpt[#excerpt + 1] = string.format("%d | %s", line_nr, lines[line_nr] or "")
  end

  return excerpt
end

---@param path string|nil
---@return table[]|nil, table|nil, string|nil
function M.collect_entries(path)
  local target, err = review_files.collect_review_files(path)
  if not target then
    return nil, nil, err
  end

  local entries = {}

  for _, review_file in ipairs(target.review_files) do
    local source_path = review_files.source_path_from_review_file(review_file)
    if source_path then
      local data = storage.read_reviews(review_file)
      if data and data.reviews then
        local current_sha = git.get_head_sha(source_path)
        local line_keys = vim.tbl_keys(data.reviews)
        table.sort(line_keys, function(a, b)
          return tonumber(a) < tonumber(b)
        end)

        for _, line_key in ipairs(line_keys) do
          for _, entry in ipairs(data.reviews[line_key]) do
            local line_start = tonumber(line_key)
            local line_end = entry.end_line

            entries[#entries + 1] = {
              source_path = source_path,
              display_path = review_files.display_path(source_path, target.target_path, target.kind),
              line_start = line_start,
              line_end = line_end,
              comment = entry.comment,
              timestamp = entry.timestamp,
              commit = entry.commit,
              is_stale = git.is_stale(entry.commit, current_sha),
              code_excerpt = read_code_excerpt(source_path, line_start, line_end or line_start),
            }
          end
        end
      end
    end
  end

  table.sort(entries, function(a, b)
    if a.display_path ~= b.display_path then
      return a.display_path < b.display_path
    end
    if a.line_start ~= b.line_start then
      return a.line_start < b.line_start
    end
    local a_end = a.line_end or a.line_start
    local b_end = b.line_end or b.line_start
    if a_end ~= b_end then
      return a_end < b_end
    end
    return a.timestamp < b.timestamp
  end)

  return entries, target, nil
end

local function location(entry)
  if entry.line_end and entry.line_end ~= entry.line_start then
    return string.format("%s:%d-%d", entry.display_path, entry.line_start, entry.line_end)
  end
  return string.format("%s:%d", entry.display_path, entry.line_start)
end

---@param path string|nil
---@return string|nil, string|nil
function M.path_export_text(path)
  local entries, _, err = M.collect_entries(path)
  if not entries then
    return nil, err
  end

  if #entries == 0 then
    return "No review comments found for the selected path.", nil
  end

  local lines = {
    "Please address the following local review comments.",
    "",
  }

  for index, entry in ipairs(entries) do
    local stale_suffix = entry.is_stale and " [stale]" or ""
    lines[#lines + 1] = string.format("%d. %s%s", index, location(entry), stale_suffix)

    if entry.commit then
      lines[#lines + 1] = "   Commit: " .. entry.commit:sub(1, 7)
    end

    lines[#lines + 1] = "   Comment:"
    for _, line in ipairs(split_lines(entry.comment)) do
      lines[#lines + 1] = "     " .. line
    end

    if entry.code_excerpt and #entry.code_excerpt > 0 then
      lines[#lines + 1] = "   Code:"
      for _, code_line in ipairs(entry.code_excerpt) do
        lines[#lines + 1] = "     " .. code_line
      end
    end

    if index < #entries then
      lines[#lines + 1] = ""
    end
  end

  return table.concat(lines, "\n"), nil
end

---@param path string|nil
function M.export(path)
  local text, err = M.path_export_text(path)
  if not text then
    vim.notify(err or "[localreview] Failed to export review comments.", vim.log.levels.WARN)
    return
  end

  if #vim.api.nvim_list_uis() == 0 then
    io.write(text .. "\n")
    return
  end

  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
  vim.notify("[localreview] Exported review comments to clipboard", vim.log.levels.INFO)
end

return M
