#!/usr/bin/env -S nvim -l
--[[
-- File name: minit.lua
-- Author: Fro-Q
-- Created: 2025-11-03 00:25:18
-- Last modified: 2025-11-03 13:14:09
-- ------
-- headup.nvim minimal lazy.nvim setup for tests
--]]

---@diagnostic disable: undefined-global
vim.env.LAZY_STDPATH = ".tests"
vim.env.LAZY_PATH = vim.fs.normalize("~/projects/lazy.nvim")

if vim.fn.isdirectory(vim.env.LAZY_PATH) == 1 then
  loadfile(vim.env.LAZY_PATH .. "/bootstrap.lua")()
else
  load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"), "bootstrap.lua")()
end

-- Setup lazy
require("lazy.minit").setup({
  spec = {
    {
      dir = vim.fn.getcwd(),
      opts = {},
    },
  },
})
