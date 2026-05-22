local M = {}

---@param git_root string absolute path to git root
---@return string[] list of absolute paths to review JSON files
function M._find_review_files(git_root)
  return require("localreview.review_files").find_review_files(git_root)
end

---@return table[] entries sorted by filepath then line number (D-11)
function M._collect_entries()
  local storage = require("localreview.storage")
  local git = require("localreview.git")
  local bufpath = vim.api.nvim_buf_get_name(0)
  local git_root = git.get_git_root(bufpath)

  if not git_root then
    vim.notify("[localreview] Not in a git repository", vim.log.levels.WARN)
    return {}
  end

  local current_sha = git.get_head_sha(bufpath)
  local files = M._find_review_files(git_root)
  local entries = {}

  for _, review_file in ipairs(files) do
    local data = storage.read_reviews(review_file)
    if data and data.reviews then
      local source_path = require("localreview.review_files").source_path_from_review_file(review_file)
      if source_path then
        local rel_path = vim.fn.fnamemodify(source_path, ":~:.")

        for line_key, reviews in pairs(data.reviews) do
          for _, entry in ipairs(reviews) do
            local is_stale = git.is_stale(entry.commit, current_sha)
            local preview = entry.comment:sub(1, 60)
            local stale_prefix = is_stale and "\xF0\x9F\x92\xA4 " or ""
            local display = rel_path .. ":" .. line_key .. " " .. stale_prefix .. preview

            entries[#entries + 1] = {
              filepath = vim.fn.fnamemodify(source_path, ":p"),
              lnum = tonumber(line_key),
              display = display,
              ordinal = rel_path .. ":" .. string.format("%05d", tonumber(line_key)),
              is_stale = is_stale,
            }
          end
        end
      end
    end
  end

  table.sort(entries, function(a, b)
    return a.ordinal < b.ordinal
  end)
  return entries
end

---@param opts? table telescope picker options
function M.picker(opts)
  opts = opts or {}

  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify(
      "[localreview] Telescope not installed. Install nvim-telescope/telescope.nvim for project-wide review search.",
      vim.log.levels.WARN
    )
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local entries = M._collect_entries()

  if #entries == 0 then
    vim.notify("[localreview] No reviews found in project", vim.log.levels.INFO)
    return
  end

  pickers
    .new(opts, {
      prompt_title = "LocalReview",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(item)
          return {
            value = item,
            display = item.display,
            ordinal = item.ordinal,
            filename = item.filepath,
            lnum = item.lnum,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.file_previewer(opts),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
            vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
          end
        end)
        return true
      end,
    })
    :find()
end

return M
