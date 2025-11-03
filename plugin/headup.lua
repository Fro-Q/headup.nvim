--[[
-- File name: headup.lua
-- Author: Fro-Q
-- Created: 2025-11-03 09:37:37
-- Last modified: 2025-11-03 09:51:50
-- ------
-- headup.nvim main plugin file
--]]

---@diagnostic disable: undefined-global
-- Prevent loading twice
if vim.g.loaded_headup then
  return
end
vim.g.loaded_headup = 1

-- Create user commands
vim.api.nvim_create_user_command("HeadupEnable", function()
  require("headup").enable()
end, {
  desc = "Enable headup.nvim plugin"
})

vim.api.nvim_create_user_command("HeadupDisable", function()
  require("headup").disable()
end, {
  desc = "Disable headup.nvim plugin"
})

vim.api.nvim_create_user_command("HeadupToggle", function()
  require("headup").toggle()
end, {
  desc = "Toggle headup.nvim plugin on/off"
})

vim.api.nvim_create_user_command("HeadupUpdate", function()
  require("headup").update_current_buffer()
end, {
  desc = "Manually update metadata in current buffer"
})

vim.api.nvim_create_user_command("HeadupClearCache", function()
  require("headup").clear_cache()
end, {
  desc = "Clear headup.nvim internal cache"
})

-- Optional: Set up default configuration if user hasn't called setup
vim.defer_fn(function()
  if not vim.g.headup_setup_called then
    require("headup").setup()
  end
end, 100)
