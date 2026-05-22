local M = {}

function M.setup(opts)
  local config = require("localreview.config")
  config.setup(opts)

  vim.api.nvim_set_hl(0, "LocalReviewStale", { default = true, link = "DiagnosticHint" })

  M._register_autocmds()
  M._register_user_commands()
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

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      require("localreview.mode").sync_buffer(args.buf)
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
    require("localreview.export").export(cmd_opts.args, { include_all_sessions = cmd_opts.bang })
  end, {
    bang = true,
    nargs = "?",
    complete = "file",
    desc = "LocalReview: Export review comments for a file or directory",
  })

  vim.api.nvim_create_user_command("LocalReviewClear", function(cmd_opts)
    require("localreview.clear").clear(cmd_opts.args, { include_all_sessions = cmd_opts.bang })
  end, {
    bang = true,
    nargs = "?",
    complete = "file",
    desc = "LocalReview: Clear review comments for a file or directory",
  })

  vim.api.nvim_create_user_command("LocalReviewStart", function(cmd_opts)
    require("localreview.mode").start(cmd_opts.args)
  end, { nargs = "?", desc = "LocalReview: Start review mode" })

  vim.api.nvim_create_user_command("LocalReviewStop", function()
    require("localreview.mode").stop()
  end, { desc = "LocalReview: Stop review mode" })

  vim.api.nvim_create_user_command("LocalReviewStatus", function()
    require("localreview.mode").status()
  end, { desc = "LocalReview: Show review mode status" })
end

return M
