local storage = require("localreview.storage")
local export = require("localreview.export")
local session = require("localreview.session")

describe("localreview.export", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    session.stop()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("exports review comments for a file with code context", function()
    local source = tmpdir .. "/example.lua"
    vim.fn.writefile({ "local x = 1", "return x" }, source)

    local data = {
      reviews = {
        ["2"] = {
          { comment = "Return a better value", timestamp = 1711540800, end_line = vim.NIL, commit = vim.NIL, session_name = "review-a" },
        },
      },
    }
    storage.write_reviews(storage.review_path(source), data)

    local text = assert(export.path_export_text(source))
    assert.truthy(text:match("Please address the following local review comments"))
    assert.truthy(text:find(source .. ":2", 1, true))
    assert.truthy(text:find("Return a better value", 1, true))
    assert.truthy(text:find("2 | return x", 1, true))
  end)

  it("exports reviews from a directory in sorted order", function()
    local dir = tmpdir .. "/src"
    vim.fn.mkdir(dir, "p")
    local a = dir .. "/a.lua"
    local b = dir .. "/b.lua"
    vim.fn.writefile({ "print('a')" }, a)
    vim.fn.writefile({ "print('b')" }, b)

    storage.write_reviews(storage.review_path(b), {
      reviews = {
        ["1"] = {
          { comment = "Second file", timestamp = 20, end_line = vim.NIL, commit = vim.NIL, session_name = vim.NIL },
        },
      },
    })

    storage.write_reviews(storage.review_path(a), {
      reviews = {
        ["1"] = {
          { comment = "First file", timestamp = 10, end_line = vim.NIL, commit = vim.NIL, session_name = vim.NIL },
        },
      },
    })

    local text = assert(export.path_export_text(dir))
    local first_idx = assert(text:find("a.lua:1", 1, true))
    local second_idx = assert(text:find("b.lua:1", 1, true))
    assert.is_true(first_idx < second_idx)
  end)

  it("filters to the active review session by default", function()
    local source = tmpdir .. "/session.lua"
    vim.fn.writefile({ "return 42" }, source)

    storage.write_reviews(storage.review_path(source), {
      reviews = {
        ["1"] = {
          { comment = "From review a", timestamp = 1, end_line = vim.NIL, commit = vim.NIL, session_name = "review-a" },
          { comment = "From review b", timestamp = 2, end_line = vim.NIL, commit = vim.NIL, session_name = "review-b" },
        },
      },
    })

    session.start("review-a")
    local text = assert(export.path_export_text(source))
    assert.truthy(text:find("Review session: review-a", 1, true))
    assert.truthy(text:find("From review a", 1, true))
    assert.falsy(text:find("From review b", 1, true))

    local all_text = assert(export.path_export_text(source, { include_all_sessions = true }))
    assert.truthy(all_text:find("From review a", 1, true))
    assert.truthy(all_text:find("From review b", 1, true))
  end)

  it("returns a friendly message when no reviews exist", function()
    local source = tmpdir .. "/empty.lua"
    vim.fn.writefile({ "return true" }, source)

    local text = assert(export.path_export_text(source))
    assert.are.equal("No review comments found for the selected path.", text)
  end)
end)
