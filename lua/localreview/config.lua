local M = {}

M.defaults = {
  keys = {
    annotate = "<leader>ra",
    view = "<leader>rv",
    delete = "<leader>rd",
    next_review = "]r",
    prev_review = "[r",
    telescope = "<leader>rt",
    export = "<leader>re",
    start = "<leader>rS",
  },
  virtual_text = {
    enabled = true,
    hl_group = "Comment",
    stale_hl_group = "LocalReviewStale",
  },
  git = {
    track_commit = true,
  },
}

M.values = vim.deepcopy(M.defaults)

---@param opts table
---@return string[] unknown_keys
function M.validate_user_opts(opts)
  local unknown = {}
  for key, _ in pairs(opts) do
    if M.defaults[key] == nil then
      unknown[#unknown + 1] = key
    end
  end
  return unknown
end

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  local unknown = M.validate_user_opts(opts)
  for _, key in ipairs(unknown) do
    vim.notify("[localreview] Unknown config key: " .. key, vim.log.levels.WARN)
  end

  local keys_false = opts.keys == false

  if keys_false then
    local merged_opts = vim.deepcopy(opts)
    merged_opts.keys = nil
    M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), merged_opts)
    M.values.keys = false
  else
    M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  end
end

return M
