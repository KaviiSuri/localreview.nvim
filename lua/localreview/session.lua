local M = {}

M.current_session = nil

local function default_session_name()
  return os.date("review-%Y%m%d-%H%M%S")
end

---@param name string|nil
---@return { name: string, started_at: number }
function M.start(name)
  local session_name = vim.trim(name or "")
  if session_name == "" then
    session_name = default_session_name()
  end

  M.current_session = {
    name = session_name,
    started_at = os.time(),
  }

  return M.current_session
end

---@return { name: string, started_at: number }|nil
function M.stop()
  local previous = M.current_session
  M.current_session = nil
  return previous
end

---@return { name: string, started_at: number }|nil
function M.current()
  return M.current_session
end

---@return string|nil
function M.name()
  return M.current_session and M.current_session.name or nil
end

---@return boolean
function M.is_active()
  return M.current_session ~= nil
end

return M
