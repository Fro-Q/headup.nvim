-- File name: utils_spec.lua
-- Author: Fro-Q
-- Created: 2025-11-03 09:59:55
-- Last modified: 2025-11-04 00:31:25
-- ------
-- headup.nvim utils module tests
--]]

---@diagnostic disable: undefined-global
-- mini.test version of utils tests
local MiniTest = require('mini.test')
local Utils = require('headup.utils')

local T = MiniTest.new_set()

T["time format: detect from string"] = function()
  local text = '2024-01-15 10:30:45'
  local format = Utils.detect_time_format(text)
  assert(format ~= nil)
  assert(type(format) == 'string')
end

T["escape_pattern: escapes special characters"] = function()
  local pattern = 'test.pattern*'
  local escaped = Utils.escape_pattern(pattern)
  assert(type(escaped) == 'string')
  assert(pattern ~= escaped)
end

T["hash_content: stable across calls"] = function()
  local content = 'line1\nline2\nline3'
  local hash1 = Utils.hash_content(content)
  local hash2 = Utils.hash_content(content)
  assert(hash1 == hash2)
  assert(type(hash1) == 'string')
end

T["validate_config_item: valid config passes"] = function()
  local valid_config = {
    pattern = '*.md',
    match_pattern = 'test:%s*(.-)%s*$',
    content = 'current_time',
    time_format = 'inherit',
    max_lines = 20,
    end_pattern = '^---%s$',
  }
  local is_valid, error_msg = Utils.validate_config_item(valid_config)
  assert(is_valid == true)
  assert(error_msg == nil)
end

T["valid_contents: includes known types"] = function()
  local list = Utils.valid_contents
  assert(type(list) == 'table')
  assert(#list >= 3)
end

return T
