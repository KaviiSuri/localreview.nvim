local storage = require("localreview.storage")

describe("localreview.storage", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  describe("review_path", function()
    it("derives hidden JSON path from source file path", function()
      local result = storage.review_path("/home/user/project/foo.lua")
      assert.are.equal("/home/user/project/.foo.lua.reviews.json", result)
    end)

    it("handles init.lua correctly", function()
      local result = storage.review_path("/home/user/project/init.lua")
      assert.are.equal("/home/user/project/.init.lua.reviews.json", result)
    end)
  end)

  describe("new_review_entry", function()
    it("creates entry with comment and timestamp, nil end_line, commit, and session_name", function()
      local entry = storage.new_review_entry("This is a comment", nil)
      assert.are.equal("This is a comment", entry.comment)
      assert.is_number(entry.timestamp)
      assert.are.equal(vim.NIL, entry.end_line)
      assert.are.equal(vim.NIL, entry.commit)
      assert.are.equal(vim.NIL, entry.session_name)
    end)

    it("creates entry with end_line when provided", function()
      local entry = storage.new_review_entry("Range comment", 20, nil, "review-a")
      assert.are.equal("Range comment", entry.comment)
      assert.are.equal(20, entry.end_line)
      assert.are.equal(vim.NIL, entry.commit)
      assert.are.equal("review-a", entry.session_name)
    end)
  end)

  describe("write_reviews + read_reviews round-trip", function()
    it("round-trips data identically", function()
      local filepath = tmpdir .. "/.test.lua.reviews.json"
      local data = {
        version = 1,
        reviews = {
          ["42"] = {
            { comment = "Test comment", timestamp = 1711540800, end_line = vim.NIL, commit = vim.NIL, session_name = "review-a" },
          },
          ["15"] = {
            { comment = "Range review", timestamp = 1711540900, end_line = 20, commit = vim.NIL, session_name = vim.NIL },
          },
        },
      }

      local ok = storage.write_reviews(filepath, data)
      assert.is_true(ok)

      local read = storage.read_reviews(filepath)
      assert.is_not_nil(read)
      assert.are.equal(1, read.version)
      assert.are.equal("Test comment", read.reviews["42"][1].comment)
      assert.are.equal(1711540800, read.reviews["42"][1].timestamp)
      assert.is_nil(read.reviews["42"][1].end_line)
      assert.is_nil(read.reviews["42"][1].commit)
      assert.are.equal("review-a", read.reviews["42"][1].session_name)
      assert.are.equal("Range review", read.reviews["15"][1].comment)
      assert.are.equal(1711540900, read.reviews["15"][1].timestamp)
      assert.are.equal(20, read.reviews["15"][1].end_line)
      assert.is_nil(read.reviews["15"][1].session_name)
    end)

    it("written JSON contains version=1 at top level", function()
      local filepath = tmpdir .. "/.test.lua.reviews.json"
      local data = { reviews = { ["1"] = {} } }

      storage.write_reviews(filepath, data)

      local lines = vim.fn.readfile(filepath)
      local content = table.concat(lines, "\n")
      local decoded = vim.json.decode(content)
      assert.are.equal(1, decoded.version)
    end)

    it("reviews are keyed by string line number", function()
      local filepath = tmpdir .. "/.test.lua.reviews.json"
      local data = {
        version = 1,
        reviews = {
          ["42"] = {
            { comment = "test", timestamp = 123, end_line = vim.NIL, commit = vim.NIL },
          },
        },
      }

      storage.write_reviews(filepath, data)
      local read = storage.read_reviews(filepath)
      assert.is_not_nil(read.reviews["42"])
      assert.is_nil(read.reviews[42])
    end)

    it("does NOT leave temp file behind on success", function()
      local filepath = tmpdir .. "/.test.lua.reviews.json"
      local data = { version = 1, reviews = {} }

      storage.write_reviews(filepath, data)

      local files = vim.fn.glob(tmpdir .. "/.localreview_tmp_*", false, true)
      assert.are.equal(0, #files)
    end)
  end)

  describe("read_reviews edge cases", function()
    it("returns nil for non-existent file", function()
      local result = storage.read_reviews(tmpdir .. "/nonexistent.json")
      assert.is_nil(result)
    end)

    it("returns nil for empty file", function()
      local filepath = tmpdir .. "/empty.json"
      vim.fn.writefile({}, filepath)
      local result = storage.read_reviews(filepath)
      assert.is_nil(result)
    end)

    it("returns nil for corrupted JSON", function()
      local filepath = tmpdir .. "/corrupt.json"
      vim.fn.writefile({ "not valid json {{{{" }, filepath)
      local result = storage.read_reviews(filepath)
      assert.is_nil(result)
    end)
  end)

  describe("get_buf_filepath", function()
    it("returns nil for empty bufname", function()
      -- Create a scratch buffer with no name
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      local result = storage.get_buf_filepath()
      assert.is_nil(result)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
