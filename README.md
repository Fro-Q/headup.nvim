# headup.nvim

<p align="center">

*Automatically updates file metadata on save.*

</p>

## Demo

https://github.com/Fro-Q/headup.nvim/raw/main/assets/headup_demo.mp4

## Features

- Automatic updates for header metadata on write
- Respects manual edits (won’t overwrite user changes)
- Per-filetype rules with globs, early-stop scanning, and exclusions

## Built-in supported content

- `current_time`: Current timestamp with customizable format
- `file_size`: Humanized file size (B / KB / MB / GB / TB)
- `line_count`: Number of lines in the buffer
- `file_name`: Base filename
- `file_path`: Path relative to CWD
- `file_path_abs`: Absolute path

See also: `:help Utils.valid_contents`.

## Install

Using lazy.nvim

```lua
{
  "Fro-Q/headup.nvim",
  config = function()
    require("headup").setup()
  end,
}
```

Using packer.nvim

```lua
use {
  "Fro-Q/headup.nvim",
  config = function()
    require("headup").setup()
  end
}
```

## Quick start

Minimal setup that updates something like `-- Last Modified: x` in Lua with current time in the specified format, stopping at the first empty line.

```lua
require("headup").setup({
  enabled = true,
  silent = true,
  time_format = "%Y-%m-%d %H:%M:%S",
  max_lines = 20,
  end_pattern = "^%s*$", -- stop at first empty line
  exclude_pattern = "",
  {
    pattern = "*.lua",
    match_pattern = "^%s*%-%-%s*[Ll]ast[%s_%-][Mm]odified:%s(.-)%s*$",
    content = "current_time",
  },
})
```

## Configuration overview

- Global options (apply to all items unless overridden):
  - `enabled` (boolean, default `true`)
  - `silent` (boolean, default `true`)
  - `time_format` (string|"inherit")
  - `max_lines` (number)
  - `end_pattern` (string, Lua pattern; early stop when matched)
  - `exclude_pattern` (string|string[]; file globs to skip)

- Per-item options (each element is a rule):
  - `pattern` (string|string[]; file globs for autocmd)
  - `match_pattern` (string; Lua pattern to capture the value to replace)
  - `content` (string; one of supported content types)
  - `time_format` (string|"inherit")
  - `max_lines` (number)
  - `end_pattern` (string)
  - `exclude_pattern` (string|string[])

Note: items inherit unset values from global options (fallbacks).

## Commands and API

- `:HeadupEnable` / `:HeadupDisable` / `:HeadupToggle`
- `:HeadupUpdate` – force update current buffer (ignores previous cache and buffer state)
- `:HeadupClearCache` – clear internal cache

Lua API (see :help Headup):

- Some commands have equivalent Lua functions:
  - `require('headup').enable()` / `disable()` / `toggle()`
  - `require('headup').update_current_buffer()`
  - `require('headup').clear_cache()`
- You can register custom content generators:
  - `require('headup.func').register_generator(name, func)`

See more in `:help headup.nvim`.

## Extend: custom content generators

You can add your own content type by registering a generator. A generator is
`fun(bufnr: integer, ctx?: { time_format?: string, old_content?: string }): string`.

Register:

```lua
local func = require('headup.func')

func.register('my_branch', function(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  local dir = file ~= '' and vim.fn.fnamemodify(file, ':h') or vim.fn.getcwd()
  local out = vim.fn.systemlist({ 'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD' })
  local branch = (out and out[1]) or 'unknown'
  return (branch or ''):gsub('%s+', '')
end)
```

Use in config:

```lua
require('headup').setup({
  {
    pattern = '*.md',
    match_pattern = 'branch:%s*(.-)%s*$',
    content = 'my_branch',
  },
})
```

More templates:

```lua
-- Uppercase previous value
func.register('uppercase', function(_, ctx)
  return ((ctx and ctx.old_content) or ''):upper()
end)

-- SHA256 of current buffer
func.register('file_sha256', function(bufnr)
  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  return vim.fn.sha256(text)
end)
```

And share your useful generators in [Discussions](https://github.com/Fro-Q/headup.nvim/discussions)!

## Help

There is a most detailed help file included with the plugin. See in `:help headup.nvim`.

## License

<p align="center">
MIT - Copyright (c) 2025 Fro-Q
</p>
