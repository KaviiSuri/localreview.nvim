local M = {}

function M.setup(opts)
  local config = require("localreview.config")
  config.setup(opts)

  vim.api.nvim_set_hl(0, "LocalReviewStale", { default = true, link = "DiagnosticHint" })

  if config.values.keys ~= false then
    M._register_keybindings(config.values.keys)
  end

  M._register_autocmds()
  M._register_user_commands()
end

---@param keys table
function M._register_keybindings(keys)
  local bindings = {
    {
      keys.annotate,
      function()
        require("localreview.annotations").annotate()
      end,
      { "n", "v" },
      "LocalReview: Annotate line",
    },
    {
      keys.view,
      function()
        require("localreview.display").view_reviews()
      end,
      { "n" },
      "LocalReview: View reviews",
    },
    {
      keys.delete,
      function()
        require("localreview.annotations").delete_review()
      end,
      { "n" },
      "LocalReview: Delete review",
    },
    {
      keys.next_review,
      function()
        require("localreview.navigation").next_review()
      end,
      { "n" },
      "LocalReview: Next review",
    },
    {
      keys.prev_review,
      function()
        require("localreview.navigation").prev_review()
      end,
      { "n" },
      "LocalReview: Previous review",
    },
    {
      keys.telescope,
      function()
        require("localreview.telescope").picker()
      end,
      { "n" },
      "LocalReview: Telescope reviews",
    },
    {
      keys.export,
      function()
        require("localreview.export").export()
      end,
      { "n" },
      "LocalReview: Export review comments",
    },
  }

  for _, binding in ipairs(bindings) do
    local lhs, rhs, modes, desc = binding[1], binding[2], binding[3], binding[4]
    if lhs and lhs ~= "" then
      vim.keymap.set(modes, lhs, rhs, { desc = desc })
    end
  end
end

function M._register_autocmds()
  local group = vim.api.nvim_create_augroup("localreview", { clear = true })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      local bufpath = vim.api.nvim_buf_get_name(args.buf)
      if bufpath == "" then
        return
      end

      local storage = require("localreview.storage")
      local review_file = storage.review_path(bufpath)
      local data = storage.read_reviews(review_file)

      if not data or not data.reviews or vim.tbl_isempty(data.reviews) then
        return
      end

      local stale_lines = nil
      local cfg = require("localreview.config").values
      if cfg.git.track_commit then
        local git = require("localreview.git")
        local current_sha = git.get_head_sha(bufpath)
        if current_sha then
          stale_lines = {}
          for line_key, reviews in pairs(data.reviews) do
            for _, entry in ipairs(reviews) do
              if git.is_stale(entry.commit, current_sha) then
                stale_lines[line_key] = true
                break
              end
            end
          end
        end
      end

      require("localreview.virtual_text").render_all(args.buf, data, stale_lines)
    end,
  })
end

function M._register_user_commands()
  vim.api.nvim_create_user_command("LocalReviewAnnotate", function(cmd_opts)
    if cmd_opts.range == 2 then
      require("localreview.annotations").annotate_range_from_lines(cmd_opts.line1, cmd_opts.line2)
    else
      require("localreview.annotations").annotate()
    end
  end, { range = true, desc = "LocalReview: Annotate line(s)" })

  vim.api.nvim_create_user_command("LocalReviewDelete", function()
    require("localreview.annotations").delete_review()
  end, { desc = "LocalReview: Delete review" })

  vim.api.nvim_create_user_command("LocalReviewView", function()
    require("localreview.display").view_reviews()
  end, { desc = "LocalReview: View reviews for current line" })

  vim.api.nvim_create_user_command("LocalReviewNext", function()
    require("localreview.navigation").next_review()
  end, { desc = "LocalReview: Jump to next review" })

  vim.api.nvim_create_user_command("LocalReviewPrev", function()
    require("localreview.navigation").prev_review()
  end, { desc = "LocalReview: Jump to previous review" })

  vim.api.nvim_create_user_command("LocalReviewTelescope", function()
    require("localreview.telescope").picker()
  end, { desc = "LocalReview: Search all reviews via Telescope" })

  vim.api.nvim_create_user_command("LocalReviewExport", function(cmd_opts)
    require("localreview.export").export(cmd_opts.args)
  end, { nargs = "?", complete = "file", desc = "LocalReview: Export review comments for a file or directory" })

  vim.api.nvim_create_user_command("LocalReviewClear", function(cmd_opts)
    require("localreview.clear").clear(cmd_opts.args)
  end, { nargs = "?", complete = "file", desc = "LocalReview: Clear review comments for a file or directory" })
end

return M
