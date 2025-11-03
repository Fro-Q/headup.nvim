---@diagnostic disable: undefined-global
-- File: lua/headup/func.lua
-- Internal helpers extracted from init.lua to keep callbacks lean

---@mod headup.func Internal helpers for headup.nvim
---@private

local utils = require("headup.utils")

local M = {}

--- Generate new content string based on content kind
---
--- @param bufnr integer
--- @param content string           -- one of: current_time|file_size|line_count|file_name|file_path|file_path_abs
--- @param time_format string|nil   -- strftime format or "inherit"
--- @param old_content string|nil   -- previous matched content (for inherit)
--- @return string
function M.generate_new_content(bufnr, content, time_format, old_content)
  if content == "current_time" then
    local format = time_format
    if format == "inherit" and old_content then
      local detected = utils.detect_time_format(old_content)
      if detected then format = detected end
    end
    if format == "inherit" or not format then format = "%Y-%m-%d %H:%M:%S" end
    return tostring(os.date(format))
  elseif content == "file_size" then
    return utils.get_file_size(bufnr)
  elseif content == "line_count" then
    return tostring(vim.api.nvim_buf_line_count(bufnr))
  elseif content == "file_name" then
    local name = vim.api.nvim_buf_get_name(bufnr)
    return name:match("[^/\\]+$") or name
  elseif content == "file_path_abs" then
    return vim.api.nvim_buf_get_name(bufnr)
  elseif content == "file_path" then
    local abs = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    if cwd and abs:sub(1, #cwd) == cwd then
      local rel = abs:sub(#cwd + 2)
      return rel ~= "" and rel or abs
    end
    return abs
  else
    vim.notify("headup.nvim: Unknown content: " .. tostring(content), vim.log.levels.ERROR)
    return old_content or ""
  end
end

--- Find first match within the first N lines with early stop at end_pattern
---
--- @param bufnr integer
--- @param item Headup.item
--- @return integer|nil idx  -- 1-based line index
--- @return string|nil match
--- @return string|nil line
function M.find_match(bufnr, item)
  local max_lines = item.max_lines or 20
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
  for idx, line in ipairs(lines) do
    local match = line:match(item.match_pattern)
    if match then
      return idx, match, line
    end
    if item.end_pattern and line:match(item.end_pattern) then
      break
    end
  end
  return nil, nil, nil
end

--- Update original cache entry
--- @param original_cache table
--- @param bufnr integer
--- @param item Headup.item
--- @param match string
--- @param idx integer  -- 1-based line index
function M.cache_original(original_cache, bufnr, item, match, idx)
  original_cache[bufnr] = original_cache[bufnr] or {}
  original_cache[bufnr][item] = { content = match, line_num = idx - 1 }
end

--- Handle BufReadPost/BufWritePost to initialize cache quickly
--- @param original_cache table
--- @param bufnr integer
--- @param item Headup.item
function M.handle_read_post(original_cache, bufnr, item)
  local idx, match = M.find_match(bufnr, item)
  if idx and match then
    M.cache_original(original_cache, bufnr, item, match, idx)
  end
end

--- Replace matched content on the line and update cache/notify
--- @param bufnr integer
--- @param idx integer
--- @param old string
--- @param new string
--- @param silent boolean
--- @param content_label string
--- @param original_cache table
--- @param item Headup.item
function M.apply_update(bufnr, idx, old, new, silent, content_label, original_cache, item)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line = all_lines[idx]
  if not line then return false end
  local updated_line = line:gsub(utils.escape_pattern(old), new)
  if updated_line == line then return false end
  all_lines[idx] = updated_line
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)

  if not silent then
    vim.notify("headup.nvim: Auto-updated " .. content_label .. " to: " .. new, vim.log.levels.INFO)
  end
  M.cache_original(original_cache, bufnr, item, new, idx)
  return true
end

--- Handle BufWritePre update logic with manual-change detection
--- @param original_cache table
--- @param bufnr integer
--- @param item Headup.item
--- @param cfg Headup.config
--- @return boolean updated  -- whether buffer was changed
function M.handle_write_pre(original_cache, bufnr, item, cfg)
  if not vim.api.nvim_get_option_value("modified", { buf = bufnr }) then return false end

  local idx, match, line = M.find_match(bufnr, item)
  if not idx or not match or not line then return false end

  local cached = original_cache[bufnr] and original_cache[bufnr][item]
  if cached and cached.content ~= match then
    if not cfg.silent then
      vim.notify("headup.nvim: Skipping automatic update due to manual change", vim.log.levels.INFO)
    end
    M.cache_original(original_cache, bufnr, item, match, idx)
    return false
  end

  local new_content = M.generate_new_content(bufnr, item.content, item.time_format or "inherit", match)
  local content_name = (utils.format_content_name and utils.format_content_name(item.content)) or item.content
  return M.apply_update(bufnr, idx, match, new_content, cfg.silent, content_name, original_cache, item)
end

return M
