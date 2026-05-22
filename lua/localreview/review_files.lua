local M = {}

local storage = require("localreview.storage")

local function normalize_path(path)
  local absolute = vim.fn.fnamemodify(path, ":p")
  if #absolute > 1 and absolute:sub(-1) == "/" then
    return absolute:sub(1, -2)
  end
  return absolute
end

---@param path string
---@return boolean
function M.is_review_file(path)
  return path:match("/%.[^/]+%.reviews%.json$") ~= nil
end

---@param review_file string
---@return string|nil
function M.source_path_from_review_file(review_file)
  local dir = vim.fn.fnamemodify(review_file, ":h")
  local name = vim.fn.fnamemodify(review_file, ":t")
  local source_name = name:match("^%.(.+)%.reviews%.json$")
  if not source_name then
    return nil
  end
  return dir .. "/" .. source_name
end

---@param dir string
---@return string[]
function M.find_review_files(dir)
  local pattern = normalize_path(dir) .. "/**/.*.reviews.json"
  local files = vim.fn.glob(pattern, false, true)
  table.sort(files)
  return files
end

---@return string
function M.default_target_path()
  local cwd = normalize_path(vim.fn.getcwd())
  local git_root = require("localreview.git").get_git_root(cwd)
  return git_root or cwd
end

---@param path string|nil
---@return string|nil, string|nil
function M.resolve_target_path(path)
  local target = path
  if not target or target == "" then
    return M.default_target_path(), nil
  end

  target = normalize_path(target)
  if vim.fn.isdirectory(target) == 1 or vim.fn.filereadable(target) == 1 then
    return target, nil
  end

  return nil, "[localreview] Path does not exist: " .. target
end

---@param path string|nil
---@return { target_path: string, kind: string, review_files: string[] }|nil, string|nil
function M.collect_review_files(path)
  local target, err = M.resolve_target_path(path)
  if not target then
    return nil, err
  end

  if vim.fn.isdirectory(target) == 1 then
    return {
      target_path = target,
      kind = "directory",
      review_files = M.find_review_files(target),
    }, nil
  end

  if M.is_review_file(target) then
    return {
      target_path = target,
      kind = "review_file",
      review_files = { target },
    }, nil
  end

  local review_file = storage.review_path(target)
  local files = {}
  if vim.fn.filereadable(review_file) == 1 then
    files = { review_file }
  end

  return {
    target_path = target,
    kind = "file",
    review_files = files,
  }, nil
end

---@param source_path string
---@param target_path string
---@param kind string
---@return string
function M.display_path(source_path, target_path, kind)
  if kind == "file" or kind == "review_file" then
    local rel = vim.fn.fnamemodify(source_path, ":.")
    return rel ~= source_path and rel or source_path
  end

  local target = normalize_path(target_path)
  local prefix = target .. "/"
  if source_path:sub(1, #prefix) == prefix then
    return source_path:sub(#prefix + 1)
  end

  local rel = vim.fn.fnamemodify(source_path, ":.")
  return rel ~= source_path and rel or source_path
end

return M
