--[[
-- File name: init.lua
-- Author: Fro-Q
-- Created: 2025-11-03 02:44:33
-- Last modified: 2025-11-03 18:52:39
-- ------
-- headup.nvim main module
--]]

---@diagnostic disable: undefined-global
require("headup.types")
local utils = require("headup.utils")
local func = require("headup.func")

--- 
---@class Headup Headup main module
---@field config Headup.config Current effective configuration
---@field setup fun(user_config: table|nil) Setup the plugin
---@field enable fun() Enable the plugin
---@field disable fun() Disable the plugin
---@field toggle fun() Toggle plugin enabled state
---@field update_current_buffer fun() Match and update the current buffer
---@field clear_cache fun() Clear internal caches
---@field get_config fun(): Headup.config Get current effective config
local Headup = {} ---@diagnostic disable-line: missing-fields

---@class Headup.config
---@field enabled boolean Whether the plugin is enabled globally
---@field silent boolean Whether to suppress notification messages when
---   updating metadata
---@field time_format string|'inherit'|nil Global fallback time format for
---   current_time
---@field max_lines number|nil Global fallback for maximum number of lines to
---   scan
---@field end_pattern string|nil Global fallback Lua pattern to stop scanning
---@field exclude_pattern string|string[]|nil Global fallback filename 
---   pattern(s) to exclude
---@field configs table<number, Headup.item> List of configuration items for 
---   different file types
---
--- Default: ~
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Headup.config = {
  enabled = true,
  silent = true,
  time_format = nil,
  max_lines = nil,
  end_pattern = nil,
  exclude_pattern = nil,
  configs = {
    {
      pattern = "*.md",
      match_pattern = "last_modified:%s*(.-)%s$",
      content = "current_time",
      time_format = "%Y-%m-%d %H:%M:%S",
      max_lines = 20,
      end_pattern = "^---%s$",
    },
  },
}
--minidoc_afterlines_end

local default_config_items = {
  {
    pattern = "*.md",
    match_pattern = "last_modified:%s*(.-)%s$",
    content = "current_time",
    time_format = "%Y-%m-%d %H:%M:%S",
    max_lines = 20,
    end_pattern = "^---%s$",
  },
}

-- Runtime caches
---@type table<number, table>
---@private
local _original_content = {}
---@type integer[]
---@private
local _autocmd_groups = {}

-- Parse user config with global fallbacks applied
---@param user_config table|nil
---@return Headup.config
---@private
local function _parse(user_config)
  local parsed = {
    enabled = true,
    silent = true,
    time_format = nil,
    max_lines = nil,
    end_pattern = nil,
    exclude_pattern = nil,
    configs = {},
  }

  if user_config then
    if user_config.enabled ~= nil then parsed.enabled = user_config.enabled end
    if user_config.silent ~= nil then parsed.silent = user_config.silent end
    if user_config.time_format ~= nil then parsed.time_format = user_config.time_format end
    if user_config.max_lines ~= nil then parsed.max_lines = user_config.max_lines end
    if user_config.end_pattern ~= nil then parsed.end_pattern = user_config.end_pattern end
    if user_config.exclude_pattern ~= nil then parsed.exclude_pattern = user_config.exclude_pattern end

    for _, v in pairs(user_config) do
      if type(v) == "table" and v.pattern then table.insert(parsed.configs, v) end
    end
  end

  if #parsed.configs == 0 then
    parsed.configs = default_config_items
  end

  for _, item in ipairs(parsed.configs) do
    if item.time_format == nil and parsed.time_format ~= nil then item.time_format = parsed.time_format end
    if item.max_lines == nil and parsed.max_lines ~= nil then item.max_lines = parsed.max_lines end
    if item.end_pattern == nil and parsed.end_pattern ~= nil then item.end_pattern = parsed.end_pattern end
    if item.exclude_pattern == nil and parsed.exclude_pattern ~= nil then item.exclude_pattern = parsed.exclude_pattern end
  end

  return parsed
end

-- Validate effective config
---@param cfg Headup.config
---@return boolean, string|nil
---@private
local function _validate(cfg)
  for i, item in ipairs(cfg.configs) do
    local ok, err = utils.validate_config_item(item)
    if not ok then return false, "config[" .. i .. "] " .. err end
  end
  return true, nil
end

--- Setup the plugin ~
---
---@usage >lua
---   require('headup').setup() -- Use default config
---   require('headup').setup({ -- Use custom config
---     -- Your config here
---   })
---@param user_config Headup.config?
Headup.setup = function(user_config)
  local parsed = _parse(user_config)
  local ok, err = _validate(parsed)
  if not ok then
    vim.notify("headup.nvim: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  Headup.config = parsed
  vim.g.headup_setup_called = true

  if Headup.config.enabled then
    Headup.enable()
  end
end

--- Enable the plugin (register autocmds)
Headup.enable = function()
  local function clear_autocmds()
    for _, group in ipairs(_autocmd_groups) do
      pcall(vim.api.nvim_clear_autocmds, { group = group })
    end
    _autocmd_groups = {}
  end

  -- Clear existing groups without flipping enabled state
  clear_autocmds()

  Headup.config.enabled = true

  -- Create autocmds per item config
  for i, item in ipairs(Headup.config.configs) do
    local patterns = item.pattern
    if type(patterns) == "string" then patterns = { patterns } end

    for _, pat in ipairs(patterns) do
      local group_name = "HeadupNvim_" .. i .. "_" .. pat:gsub("[^%w]", "_")
      local group = vim.api.nvim_create_augroup(group_name, { clear = true })
      table.insert(_autocmd_groups, group)

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = group,
        pattern = pat,
        callback = function(args)
          local fname = vim.api.nvim_buf_get_name(args.buf)
          if utils.path_matches(fname, item.exclude_pattern) then return end
          -- initialize cache quickly
          func.handle_read_post(_original_content, args.buf, item)
        end,
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = group,
        pattern = pat,
        callback = function(args)
          local fname = vim.api.nvim_buf_get_name(args.buf)
          if utils.path_matches(fname, item.exclude_pattern) then return end
          func.handle_write_pre(_original_content, args.buf, item, Headup.config)
        end,
      })
    end
  end
end

--- Disable the plugin (clear autocmds)
Headup.disable = function()
  Headup.config.enabled = false
  for _, group in ipairs(_autocmd_groups) do
    pcall(vim.api.nvim_clear_autocmds, { group = group })
  end
  _autocmd_groups = {}
end

--- Toggle plugin enabled state
Headup.toggle = function()
  local new_state = not Headup.config.enabled
  if new_state then
    Headup.enable()
  else
    Headup.disable()
  end
end

--- Update the current buffer immediately
Headup.update_current_buffer = function()
  if not Headup.config.enabled then
    vim.notify("headup.nvim is disabled", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local updated = false

  for _, item in ipairs(Headup.config.configs) do
    if utils.path_matches(filename, item.pattern) and not utils.path_matches(filename, item.exclude_pattern) then
      local idx, match, line = func.find_match(bufnr, item)
      if idx and match and line then
        local new_content = func.generate_new_content(bufnr, item.content, item.time_format or "inherit", match)
        local updated_line = line:gsub(utils.escape_pattern(match), new_content)
        if updated_line ~= line then
          local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          all_lines[idx] = updated_line
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)

          if not Headup.config.silent then
            local content_name = utils.format_content_name and utils.format_content_name(item.content) or item.content
            vim.notify("headup.nvim: Updated " .. content_name .. " to: " .. new_content, vim.log.levels.INFO)
          end
          func.cache_original(_original_content, bufnr, item, new_content, idx)
          updated = true
        end
      end
    end
  end

  if not updated then
    vim.notify("headup.nvim: No matching pattern found in current buffer", vim.log.levels.WARN)
  end
end

--- Clear internal caches and notify if not silent
Headup.clear_cache = function()
  _original_content = {}
  if not Headup.config.silent then
    vim.notify("headup.nvim cache cleared", vim.log.levels.INFO)
  end
end

--- Return current effective config table
---@return Headup.config
Headup.get_config = function()
  return Headup.config
end

return Headup
