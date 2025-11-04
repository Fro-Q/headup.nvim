--[[
-- File name: func.lua
-- Author: Fro-Q
-- Created: 2025-11-04 01:37:53
-- Last modified: 2025-11-04 02:33:55
-- ------
-- headup.nvim internal functions
--]]

---@diagnostic disable: undefined-global

---
--- With a |Func.register_generator| function, you easily can add your own
--- content generators without my permission(strike through).
---
---@tag Headup.func
---@toc_entry Internal functions

---@alias Func.content_generator fun(bufnr: integer, ctx?: { time_format?: string, old_content?: string }): string

local utils = require("headup.utils")

local Func = {}

---
--- Content generators table. Each generator is a function that takes a buffer
--- number and an optional context table, and returns a string.
---
--- Note ~
---   - You should never modify this table directly since content validation
---     won't be updated. Use |Func.register_generator| instead.
---
---@type table<string, Func.content_generator>
---@toc_entry   Content generators table
Func.content_generators = {
  current_time = function(bufnr, ctx)
    local _ = bufnr -- unused but kept for consistent signature
    local old_content = ctx and ctx.old_content or nil
    local time_format = ctx and ctx.time_format or nil
    local format = time_format
    if format == "inherit" and old_content then
      local detected = utils.detect_time_format(old_content)
      if detected then format = detected end
    end
    if format == "inherit" or not format then format = "%Y-%m-%d %H:%M:%S" end
    return tostring(os.date(format))
  end,

  file_size = function(bufnr)
    return utils.get_file_size(bufnr)
  end,

  line_count = function(bufnr)
    return tostring(vim.api.nvim_buf_line_count(bufnr))
  end,

  file_name = function(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    return name:match("[^/\\]+$") or name
  end,

  file_path_abs = function(bufnr)
    return vim.api.nvim_buf_get_name(bufnr)
  end,

  file_path = function(bufnr)
    local abs = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    if cwd and abs:sub(1, #cwd) == cwd then
      local rel = abs:sub(#cwd + 2)
      return rel ~= "" and rel or abs
    end
    return abs
  end,
}

---
--- Register a new content generator.
---
---@usage >lua
---   local func = require('headup.func')
---   func.register('my_generator', function(bufnr, ctx)
---     -- Your generation logic here
---     return "generated content"
---   end)
---
--- Then in your configuration, you can use:
---@text >lua
---   require('headup').setup({
---     {
---       pattern = '*.txt',
---       match_pattern = 'custom:%s*(.-)%s*$',
---       content = 'my_generator',
---     }
---   })
---@text
--- It will match lines like `custom: old_value` and replace `old_value` with
--- the output of your `my_generator` function. Just works!
---
---@param name string
---@param generator Func.content_generator
---     Register a new content generator. See below:
---
---     Parameters ~
---     {bufnr} `(integer)`
---         Buffer number. 0 for current buffer.
---     {ctx?} `(table|nil)`
---         Optional context table with:
---         {time_format?} `(string|nil)`
---             Time format string for time-based generators.
---         {old_content?} `(string|nil)`
---             Previous matched content for "inherit" formats.
---
---     Returns ~
---     `(string)`
---         Generated content.
---
---@toc_entry   Register a new content generator!
function Func.register_generator(name, generator)
  if type(name) ~= "string" or name == "" then
    vim.notify("headup.nvim: register(): invalid name", vim.log.levels.ERROR)
    return
  end
  if type(generator) ~= "function" then
    vim.notify("headup.nvim: register(): generator must be a function", vim.log.levels.ERROR)
    return
  end

  Func.content_generators[name] = generator

  -- Ensure Utils.valid_contents contains the new key
  local exists = false
  for _, v in ipairs(utils.valid_contents) do
    if v == name then
      exists = true; break
    end
  end
  if not exists then table.insert(utils.valid_contents, name) end
end

--- Generate new content string based on content kind. You don't have to call
--- this directly.
---
---@param bufnr integer
---@param content string
---     See |Utils.valid_contents| for built-in content types, or create your
---     own with |Func.register_generator|.
---@param time_format string|nil
---     Strftime format string for time-based content. Use "inherit" to detect
---     from previous content.
---@param old_content string|nil
---     Previous matched content, used for detecting if the content has been
---     manually changed.
---
---@return string
---     Generated content string.
---@toc_entry   Generate new content
function Func.generate_new_content(bufnr, content, time_format, old_content)
  local gen = Func.content_generators[content]
  if not gen then
    vim.notify("headup.nvim: Unknown content: " .. tostring(content), vim.log.levels.ERROR)
    return old_content or ""
  end
  return gen(bufnr, { time_format = time_format, old_content = old_content })
end

--- Find first match within the first N lines with early stop at end_pattern
---
---@param bufnr integer
---@param item Headup.item
---@return integer|nil idx  -- 1-based line index
---@return string|nil match
---@return string|nil line
---@private
function Func.find_match(bufnr, item)
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
---@param original_cache table
---@param bufnr integer
---@param item Headup.item
---@param match string
---@param idx integer  -- 1-based line index
---@private
function Func.cache_original(original_cache, bufnr, item, match, idx)
  original_cache[bufnr] = original_cache[bufnr] or {}
  original_cache[bufnr][item] = { content = match, line_num = idx - 1 }
end

--- Handle BufReadPost/BufWritePost to initialize cache quickly
---@param original_cache table
---@param bufnr integer
---@param item Headup.item
---@private
function Func.handle_read_post(original_cache, bufnr, item)
  local idx, match = Func.find_match(bufnr, item)
  if idx and match then
    Func.cache_original(original_cache, bufnr, item, match, idx)
  end
end

--- Replace matched content on the line and update cache/notify
---@param bufnr integer
---@param idx integer
---@param old string
---@param new string
---@param silent boolean
---@param content_label string
---@param original_cache table
---@param item Headup.item
---@private
function Func.apply_update(bufnr, idx, old, new, silent, content_label, original_cache, item)
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
  Func.cache_original(original_cache, bufnr, item, new, idx)
  return true
end

--- Handle BufWritePre update logic with manual-change detection
---@param original_cache table
---@param bufnr integer
---@param item Headup.item
---@param cfg Headup.config
---@return boolean updated  -- whether buffer was changed
---@private
function Func.handle_write_pre(original_cache, bufnr, item, cfg)
  if not vim.api.nvim_get_option_value("modified", { buf = bufnr }) then return false end

  local idx, match, line = Func.find_match(bufnr, item)
  if not idx or not match or not line then return false end

  local cached = original_cache[bufnr] and original_cache[bufnr][item]
  if cached and cached.content ~= match then
    if not cfg.silent then
      vim.notify("headup.nvim: Skipping automatic update due to manual change", vim.log.levels.INFO)
    end
    Func.cache_original(original_cache, bufnr, item, match, idx)
    return false
  end

  local new_content = Func.generate_new_content(bufnr, item.content, item.time_format or "inherit", match)
  local content_name = (utils.format_content_name and utils.format_content_name(item.content)) or item.content
  return Func.apply_update(bufnr, idx, match, new_content, cfg.silent, content_name, original_cache, item)
end

---
--- If you made it this far and wish to know more, I assume you want to contribute
--- to the project. Feel free to open an issue or a pull request on GitHub!

return Func
