local M = {}

local function keymap_specs()
  return {
    {
      lhs = require("localreview.config").values.keys.annotate,
      rhs = function()
        require("localreview.annotations").annotate()
      end,
      modes = { "n", "v" },
      desc = "LocalReview: Annotate line",
    },
    {
      lhs = require("localreview.config").values.keys.view,
      rhs = function()
        require("localreview.display").view_reviews()
      end,
      modes = { "n" },
      desc = "LocalReview: View reviews",
    },
    {
      lhs = require("localreview.config").values.keys.delete,
      rhs = function()
        require("localreview.annotations").delete_review()
      end,
      modes = { "n" },
      desc = "LocalReview: Delete review",
    },
    {
      lhs = require("localreview.config").values.keys.next_review,
      rhs = function()
        require("localreview.navigation").next_review()
      end,
      modes = { "n" },
      desc = "LocalReview: Next review",
    },
    {
      lhs = require("localreview.config").values.keys.prev_review,
      rhs = function()
        require("localreview.navigation").prev_review()
      end,
      modes = { "n" },
      desc = "LocalReview: Previous review",
    },
    {
      lhs = require("localreview.config").values.keys.telescope,
      rhs = function()
        require("localreview.telescope").picker()
      end,
      modes = { "n" },
      desc = "LocalReview: Telescope reviews",
    },
    {
      lhs = require("localreview.config").values.keys.export,
      rhs = function()
        require("localreview.export").export()
      end,
      modes = { "n" },
      desc = "LocalReview: Export review comments",
    },
  }
end

---@param buf number
---@return boolean
function M.eligible_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if vim.api.nvim_buf_get_name(buf) == "" or vim.bo[buf].buftype ~= "" then
    return false
  end

  local filetype = vim.bo[buf].filetype or ""
  if filetype:match("^octo") then
    return false
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.wo[win].diff then
      return false
    end
  end

  return true
end

---@param buf number
function M.attach_buffer(buf)
  local keys = require("localreview.config").values.keys
  if keys == false or not require("localreview.session").is_active() or not M.eligible_buffer(buf) then
    return
  end

  if vim.b[buf].localreview_mode_attached then
    return
  end

  for _, spec in ipairs(keymap_specs()) do
    if spec.lhs and spec.lhs ~= "" then
      vim.keymap.set(spec.modes, spec.lhs, spec.rhs, { buffer = buf, desc = spec.desc })
    end
  end

  vim.b[buf].localreview_mode_attached = true
end

---@param buf number
function M.detach_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.b[buf].localreview_mode_attached then
    return
  end

  for _, spec in ipairs(keymap_specs()) do
    if spec.lhs and spec.lhs ~= "" then
      for _, mode in ipairs(spec.modes) do
        pcall(vim.keymap.del, mode, spec.lhs, { buffer = buf })
      end
    end
  end

  vim.b[buf].localreview_mode_attached = false
end

---@param buf number
function M.sync_buffer(buf)
  if require("localreview.session").is_active() and M.eligible_buffer(buf) then
    M.attach_buffer(buf)
  else
    M.detach_buffer(buf)
  end
end

function M.sync_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.sync_buffer(buf)
  end
end

---@param name string|nil
function M.start(name)
  local session = require("localreview.session").start(name)
  M.sync_all_buffers()
  vim.notify("[localreview] Review mode started: " .. session.name, vim.log.levels.INFO)
end

function M.stop()
  local session = require("localreview.session").stop()
  M.sync_all_buffers()

  if session then
    vim.notify("[localreview] Review mode stopped: " .. session.name, vim.log.levels.INFO)
  else
    vim.notify("[localreview] Review mode is not active", vim.log.levels.INFO)
  end
end

function M.status()
  local session = require("localreview.session").current()
  if session then
    vim.notify("[localreview] Active review mode: " .. session.name, vim.log.levels.INFO)
  else
    vim.notify("[localreview] Review mode is inactive", vim.log.levels.INFO)
  end
end

return M
