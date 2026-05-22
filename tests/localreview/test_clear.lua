local storage = require("localreview.storage")
local clear = require("localreview.clear")
local session = require("localreview.session")

describe("localreview.clear", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    session.stop()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("clears a single file review", function()
    local source = tmpdir .. "/one.lua"
    vim.fn.writefile({ "return 1" }, source)
    local review_file = storage.review_path(source)
    storage.write_reviews(review_file, {
      reviews = {
        ["1"] = {
          { comment = "Fix me", timestamp = 1, end_line = vim.NIL, commit = vim.NIL, session_name = vim.NIL },
        },
      },
    })

    local deleted = assert(clear.clear_path(source))
    assert.are.equal(1, deleted)
    assert.are.equal(0, vim.fn.filereadable(review_file))
  end)

  it("clears all review files under a directory", function()
    local dir = tmpdir .. "/src"
    vim.fn.mkdir(dir .. "/nested", "p")
    local source_a = dir .. "/a.lua"
    local source_b = dir .. "/nested/b.lua"
    vim.fn.writefile({ "return 'a'" }, source_a)
    vim.fn.writefile({ "return 'b'" }, source_b)

    storage.write_reviews(storage.review_path(source_a), {
      reviews = {
        ["1"] = {
          { comment = "A", timestamp = 1, end_line = vim.NIL, commit = vim.NIL, session_name = vim.NIL },
        },
      },
    })
    storage.write_reviews(storage.review_path(source_b), {
      reviews = {
        ["1"] = {
          { comment = "B", timestamp = 1, end_line = vim.NIL, commit = vim.NIL, session_name = vim.NIL },
        },
      },
    })

    local deleted = assert(clear.clear_path(dir))
    assert.are.equal(2, deleted)
    assert.are.equal(0, vim.fn.filereadable(storage.review_path(source_a)))
    assert.are.equal(0, vim.fn.filereadable(storage.review_path(source_b)))
  end)

  it("clears only the active session by default", function()
    local source = tmpdir .. "/session.lua"
    vim.fn.writefile({ "return true" }, source)
    local review_file = storage.review_path(source)

    storage.write_reviews(review_file, {
      reviews = {
        ["1"] = {
          { comment = "A", timestamp = 1, end_line = vim.NIL, commit = vim.NIL, session_name = "review-a" },
          { comment = "B", timestamp = 2, end_line = vim.NIL, commit = vim.NIL, session_name = "review-b" },
        },
      },
    })

    session.start("review-a")
    local deleted = assert(clear.clear_path(source))
    assert.are.equal(1, deleted)

    local remaining = assert(storage.read_reviews(review_file))
    assert.are.equal(1, #remaining.reviews["1"])
    assert.are.equal("review-b", remaining.reviews["1"][1].session_name)

    local deleted_all = assert(clear.clear_path(source, { include_all_sessions = true }))
    assert.are.equal(1, deleted_all)
    assert.are.equal(0, vim.fn.filereadable(review_file))
  end)

  it("returns zero when there are no review files", function()
    local source = tmpdir .. "/clean.lua"
    vim.fn.writefile({ "return true" }, source)

    local deleted = assert(clear.clear_path(source))
    assert.are.equal(0, deleted)
  end)
end)
