-- scripts/minidoc.lua
local minidoc = require('mini.doc')

local config = {
  hooks = vim.tbl_deep_extend('force', minidoc.default_hooks, {
  }),
}

local input_files = {
  'lua/headup/intro.lua',
  -- 'lua/headup/types.lua',
  'lua/headup/init.lua',
  'lua/headup/utils.lua',
}

local output_file = 'doc/headup.txt'

minidoc.generate(input_files, output_file, config)
