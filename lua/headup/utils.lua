--[[
-- File name: utils.lua
-- Author: Fro-Q
-- Created: 2025-11-03 02:10:37
-- Last modified: 2025-11-04 02:27:00
-- ------
-- headup.nvim utility functions
--]]

---@diagnostic disable: undefined-global

---
--- Those functions are internal helpers for headup.nvim. In most cases,
--- you won't need to interact with them directly. But who knows?
---
---@tag Headup.utils
---@toc_entry Utility functions
local Utils = {}

---
--- Useable content types for |Headup.item|.content. If you want to add more
--- content types, use |Func.register_generator|.
---
---@type string[]
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@toc_entry   Valid contents to used in `content` field
Utils.valid_contents = {
  "current_time", -- Current time with a specified format
  "file_size", -- File size, auto-converted to appropriate unit
  "line_count", -- Number of lines in the file
  "file_name", -- Base filename of the buffer
  "file_path", -- File path relative to current working directory
  "file_path_abs", -- Absolute file path
}
--minidoc_afterlines_end

---
--- Common time format patterns and their corresponding strftime formats. Used
--- for detecting time format from existing timestamps when 'time_format' is
--- set to "inherit".
---
--- Note ~
---   - This one is so ugly. But I can't find a way to parse time formats
---     properly in Lua. |HELP_WANTED|
---   - Those area Lua patterns, not regex!
---   - Tip is DON'T use "inherit" if you can set a specific format.
---
---@type table<string, string>
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@toc_entry   Time formats for `time_format: "inherit"`
Utils.time_formats = {
  -- ISO formats
  ["%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d"] = "%Y-%m-%d %H:%M:%S",
  ["%d%d%d%d%-%d%d%-%d%d"] = "%Y-%m-%d",
  ["%d%d%d%d%/%d%d%/%d%d"] = "%Y/%m/%d",
  ["%d%d%/%d%d%/%d%d%d%d"] = "%m/%d/%Y",
  -- RFC formats
  ["%a, %d %b %d%d%d%d %d%d:%d%d:%d%d"] = "%a, %d %b %Y %H:%M:%S",
  -- Unix timestamp (numeric)
  ["^%d+$"] = "timestamp",
  -- ISO 8601
  ["%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d"] = "%Y-%m-%dT%H:%M:%S",
}

---
--- Check if content type is valid. Simply checks against |Utils.valid_contents|.
---
---@param content string
---
---@return boolean
---@toc_entry   Validate content type
Utils.is_valid_content = function(content)
  for _, valid_type in ipairs(Utils.valid_contents) do
    if content == valid_type then
      return true
    end
  end
  return false
end

---
--- Simple hash function for content change detection.
---
---@param content string
---
---@return string
---@toc_entry   Hash content
Utils.hash_content = function(content)
  -- Use a simple multiplicative hash to avoid LuaJIT bitwise operator issues
  local hash = 0
  for i = 1, #content do
    local char = string.byte(content, i)
    -- Multiply by a small prime and add byte value, then wrap to 32-bit range
    hash = (hash * 31 + char) % 4294967296
  end
  return tostring(hash)
end

---
--- Detect time format from existing time string
---
---@param time_string string
---
---@return string|nil
---     Format string in strftime format if detected, or nil.
---@toc_entry   Detect time format from string
Utils.detect_time_format = function(time_string)
  if not time_string or time_string == "" then
    return nil
  end

  -- Trim whitespace
  time_string = time_string:gsub("^%s*(.-)%s*$", "%1")

  -- Check against known patterns
  for pattern, format in pairs(Utils.time_formats) do
    if time_string:match(pattern) then
      return format
    end
  end

  -- Default fallback
  return "%Y-%m-%d %H:%M:%S"
end

---
--- Get file size for current buffer.
---
---@param bufnr number
---     Buffer number. 0 for current buffer.
---
---@return string
---     File size as string with units.
---@toc_entry   Get file size
Utils.get_file_size = function(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" then
    return "0 B" -- Unnamed buffer
  end

  -- TODO: `vim.loop` is to be removed in Neovim 1.0 so this should be updated later
  ---@diagnostic disable-next-line: undefined-field
  local stat = vim.loop.fs_stat(filename)
  if not stat then
    return "0 B" -- File doesn't exist yet
  end

  local size = stat.size
  local units = { "B", "KB", "MB", "GB", "TB" }
  local unit_index = 1

  while size >= 1024 and unit_index < #units do
    size = size / 1024
    unit_index = unit_index + 1
  end

  if unit_index == 1 then
    return string.format("%d %s", size, units[unit_index])
  else
    return string.format("%.1f %s", size, units[unit_index])
  end
end

---
--- Escape special pattern characters for Lua patterns.
---
---@param str string
---
---@return string
---@toc_entry   Escape Lua pattern special characters
Utils.escape_pattern = function(str)
  -- Escape Lua pattern magic chars: ( ) . % + - * ? [ ] ^ $
  local escaped = str:gsub("[%(%).%%%+%-%*%?%[%]%^%$]", "%%%1")
  return escaped
end

---
--- Parse and validate a configuration item.
---
---@param item_config Headup.item
---     (|Headup.item|) Configuration item to validate.
---
---@return boolean, string|nil
---     True if valid, error message if invalid.
---@toc_entry   Validate configuration item
Utils.validate_config_item = function(item_config)
  -- pattern (filename pattern for autocmd)
  if not item_config.pattern then
    return false, "Missing pattern (filename glob or list of globs)"
  end
  if type(item_config.pattern) ~= "string" and type(item_config.pattern) ~= "table" then
    return false, "Invalid pattern: must be string or string[]"
  end

  -- match_pattern (Lua pattern within file content)
  if not item_config.match_pattern then
    return false, "Missing match_pattern"
  end
  if type(item_config.match_pattern) ~= "string" then
    return false, "Invalid match_pattern: must be string"
  end
  local ok, err = pcall(string.match, "test", item_config.match_pattern)
  if not ok then
    return false, "Invalid match_pattern: " .. err
  end

  -- content
  if not item_config.content then
    return false, "Missing content"
  end
  if not Utils.is_valid_content(item_config.content) then
    return false, "Invalid content: " .. tostring(item_config.content)
  end

  -- Optional end_pattern validation (Lua pattern)
  if item_config.end_pattern ~= nil then
    if type(item_config.end_pattern) ~= "string" then
      return false, "Invalid end_pattern: must be a string Lua pattern"
    end
    local ok_end, err_end = pcall(string.match, "test", item_config.end_pattern)
    if not ok_end then
      return false, "Invalid end_pattern: " .. err_end
    end
  end

  -- Optional exclude_pattern (filename glob(s))
  if item_config.exclude_pattern ~= nil then
    if type(item_config.exclude_pattern) ~= "string" and type(item_config.exclude_pattern) ~= "table" then
      return false, "Invalid exclude_pattern: must be string or string[]"
    end
  end

  -- Set defaults
  item_config.max_lines = item_config.max_lines or 20
  item_config.time_format = item_config.time_format or "inherit"

  return true, nil
end

--- Format content type name for display
---@param content string
---@return string
---@private
Utils.format_content_name = function(content)
  local names = {
    current_time = "timestamp",
    file_size = "file size",
    line_count = "line count",
    file_name = "file name",
    file_path = "file path",
    file_path_abs = "absolute file path",
  }
  return names[content] or content
end

---
--- Convert a shell-like glob (used by autocmd patterns) to a Lua pattern.
---
---@param glob string
---
---@return string
---@toc_entry   Glob to Lua pattern
Utils.glob_to_lua_pattern = function(glob)
  local p = glob
  p = p:gsub("([%^%$%(%)%%%.%+%-%[%]])", "%%%1")
  p = p:gsub("%*%*", ".*")
  p = p:gsub("%*", "[^/]*")
  p = p:gsub("%?", ".")
  return "^" .. p .. "$"
end

---
--- Check if a filepath matches one or more globs.
---
---@param filepath string
---     File path to check.
---@param patterns string|string[]|nil
---     Glob or list of globs to match against. If nil, always returns false.
---
---@return boolean
---     True if filepath matches any of the globs.
---@toc_entry   File exclusion matching
Utils.path_matches = function(filepath, patterns)
  if not patterns then
    return false
  end
  local list = {}
  if type(patterns) == "string" then
    list = { patterns }
  else
    list = patterns
  end
  for _, glob in ipairs(list) do
    local lua_pat = Utils.glob_to_lua_pattern(glob)
    if filepath:match(lua_pat) then
      return true
    end
  end
  return false
end

return Utils
