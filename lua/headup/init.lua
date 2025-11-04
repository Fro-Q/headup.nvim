--[[
-- File name: init.lua
-- Author: Fro-Q
-- Created: 2025-11-03 02:44:33
-- Last modified: 2025-11-04 02:44:08
-- ------
-- headup.nvim main module
--]]

---@diagnostic disable: undefined-global

---
--- Main module for headup.nvim. Provides setup and some high level functions.
---
---@tag Headup.core(Headup)
---@toc_entry Core
local utils = require("headup.utils")
local func = require("headup.func")


---@class Headup
---     (|Headup|): Headup main module.
---
---@field config Headup.config
---     (|Headup.config|): Current effective configuration.
---@field setup fun(user_config: table|nil)
---     (|Headup.setup()|): Setup the plugin.
---@field enable fun()
---     (|Headup.enable()|): Enable the plugin.
---@field disable fun()
---     (|Headup.disable()|): Disable the plugin.
---@field toggle fun()
---     (|Headup.toggle()|): Toggle plugin enabled state.
---@field update_current_buffer fun()
---     (|Headup.update_current_buffer()|): Match and update the current buffer.
---@field clear_cache fun()
---     (|Headup.clear_cache()|): Clear internal caches.
---@field get_config fun(): Headup.config
---     (|Headup.get_config()|): Get current effective config. See more in:
---       - |Headup.config|
---@toc_entry   Headup core module
local Headup = {} ---@diagnostic disable-line: missing-fields

---@class Headup.config
---     (|Headup.config|): Configuration table for headup.nvim.
---
---@field enabled boolean
---     Whether the plugin is enabled globally
---@field silent boolean
---     Whether to suppress notification messages when updating metadata
---@field time_format? string|'inherit'|nil
---     Global fallback time format for current_time
---@field max_lines? number|nil Global fallback for maximum number of lines to scan
---     Global fallback for maximum number of lines to scan
---@field end_pattern? string|nil
---     Global fallback Lua pattern to stop scanning
---@field exclude_pattern? string|string[]|nil
---     Global fallback filename pattern(s) to exclude
---@field configs? table<number, Headup.item>
---     List of configuration items for different file types. See more in:
---       - |Headup.item|
---
--- Default: ~
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@toc_entry   Configuration
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

---@signature Headup.item
---
---@class Headup.item
---     (|Headup.item|): Configuration item for specific file types.
---
---@field pattern string|string[]
---     File name pattern(s) for autocmd (e.g., "*.md" or {"*.md","*.markdown"})
---@field match_pattern string
---     Lua pattern to find the value to update within file content
---@field content string
---     Type of content to update. Must be one of: "current_time", "file_size",
---     "line_count", "file_name", "file_path", "file_path_abs". See |Headup.intro|
---     for details. New ideas are welcome.
---@field time_format? string|'inherit'
---     Time format string for current_time, 'inherit' to keep original format
---     Note that 'inherit' is buggy. Use with caution.
---@field max_lines? number
---     Maximum number of lines to search from the beginning
---@field end_pattern? string|nil
---     Optional Lua pattern; stop scanning when a line matches this (prevents
---     over-scanning)
---@field exclude_pattern? string|string[]|nil
---     File name pattern(s) to exclude from processing
---@tag Headup.item
---@toc_entry   Each configuration item
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

---
--- Setup the plugin.
---
---@usage >lua
---   require('headup').setup() -- Use default config
---   require('headup').setup({ -- Use custom config
---     -- Your config here
---   })
---
---@param user_config Headup.config?
---    User configuration table. See more in:
---      - |Headup.config|
---@toc_entry   Setup
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

---
--- Core functions to help you manage the plugin.
---
---@tag Headup.core.functions
---@toc_entry   Core functions

---
--- Enable the plugin. Register autocmds per config item.
---@toc_entry     Enable the plugin
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

---
--- Clear all autocmds created by `headup.nvim`.
---@toc_entry     Disable the plugin
Headup.disable = function()
  Headup.config.enabled = false
  for _, group in ipairs(_autocmd_groups) do
    pcall(vim.api.nvim_clear_autocmds, { group = group })
  end
  _autocmd_groups = {}
end

---
--- Toggle plugin enabled state.
---@toc_entry     ...Or just toggle state
Headup.toggle = function()
  local new_state = not Headup.config.enabled
  if new_state then
    Headup.enable()
  else
    Headup.disable()
  end
end

---
--- Update the current buffer immediately, ignoring caches and no-edit checks.
--- See |Headup.clear_cache()| for more details.
---@toc_entry     Kind of force-update
Headup.update_current_buffer = function()
  Headup.clear_cache()
  if not Headup.config.enabled then
    vim.notify("headup.nvim is disabled", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local updated = false

  -- Set buf modified to true to ensure BufWritePre autocmds run
  vim.api.nvim_set_option_value("modified", true, { buf = bufnr })

  -- HACK: Is it a hack?
  -- Trigger a BufWritePre autocmd to update relevant metadata
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = bufnr })

  if not updated then
    vim.notify("headup.nvim: No matching pattern found in current buffer", vim.log.levels.WARN)
  end
end

---
--- Clear internal caches.
---
--- Note ~
---   - A cache is used to track original content values. It functions to
---     prevent overwriting manual changes made by the user between automatic
---     updates.
---   - So clearing the cache will update the values anyway.
---   - It's mainly used for a force update using |Headup.update_current_buffer()|
---     to ignore previous cached values. In most cases you don't need to call
---     this.
---@toc_entry     Clear internal caches
Headup.clear_cache = function()
  _original_content = {}
  if not Headup.config.silent then
    vim.notify("headup.nvim cache cleared", vim.log.levels.INFO)
  end
end

---
--- Get current effective config.
---
--- Note ~
---   I don't think you need this.
---
---@return Headup.config
---    (|Headup.config|): Current effective config.
---@toc_entry     Get current config
Headup.get_config = function()
  return Headup.config
end

return Headup
