-- File name: types.lua
-- Author: Fro-Q
-- Created: 2025-11-03 02:21:57
-- Last modified: 2025-11-03 18:01:29
-- ------
-- headup.nvim type definitions
--]]

---@class Headup.item
---@field pattern string|string[] File name pattern(s) for autocmd (e.g., "*.md" or {"*.md","*.markdown"})
---@field match_pattern string Lua pattern to find the value to update within file content
---@field content string Type of content to update ("current_time", "file_size", "line_count", "file_name", "file_path", "file_path_abs")
---@field time_format string|'inherit' Time format string for current_time, 'inherit' to keep original format
---@field max_lines number Maximum number of lines to search from the beginning
---@field end_pattern string|nil Optional Lua pattern; stop scanning when a line matches this (prevents over-scanning)
---@field exclude_pattern string|string[]|nil File name pattern(s) to exclude from processing

return {}
