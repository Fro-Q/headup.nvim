-- Backup of previous busted-style tests for utils
---@diagnostic disable: undefined-global, undefined-field
local Utils = require('headup.utils')

describe("utils time format detection", function()
  it("should detect time format", function()
    local text = "2024-01-15 10:30:45"
    local format = Utils.detect_time_format(text)
    assert.is_not_nil(format)
    assert.are.equal("string", type(format))
  end)
end)

describe("utils pattern escaping", function()
  it("should escape special characters", function()
    local pattern = "test.pattern*"
    local escaped = Utils.escape_pattern(pattern)
    assert.are.equal("string", type(escaped))
    assert.are_not.equal(pattern, escaped)
  end)
end)

describe("utils hash content", function()
  it("should generate consistent hash", function()
    local content = "line1\nline2\nline3"
    local hash1 = Utils.hash_content(content)
    local hash2 = Utils.hash_content(content)
    assert.are.equal(hash1, hash2)
    assert.are.equal("string", type(hash1))
  end)
end)

describe("utils configuration validation", function()
  it("should validate correct config", function()
    local valid_config = {
      pattern = "*.md",
      match_pattern = "test:%s*(.-)%s*$",
      content = "current_time",
      time_format = "inherit",
      max_lines = 20,
      end_pattern = "^---%s$",
    }

    local is_valid, error_msg = Utils.validate_config_item(valid_config)
    assert.True(is_valid)
    assert.is_nil(error_msg)
  end)
end)

describe("utils content types", function()
  it("should return valid content types", function()
    local valid_types = Utils.get_valid_contents()
    assert.are.equal("table", type(valid_types))
    assert.True(#valid_types >= 3)
  end)
end)
