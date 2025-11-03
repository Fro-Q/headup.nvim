---
last_modified: 2025-11-03 17:39:38
---

# headup.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin that automatically updates file header metadata when files are saved.

## Features

- **Automatic Updates**: Automatically updates metadata in file headers when saving
- **Respects Manual Edits**: Won't overwrite user manual changes to metadata
- **Configurable**: Support multiple file types with different patterns

## Supported Content

- `current_time`: Current timestamp
- `file_size`: File size with automatic unit conversion (B, KB, MB, GB, TB)
- `line_count`: Number of lines in the file
- `file_name`: The base filename of the buffer
- `file_path`: File path relative to current working directory
- `file_path_abs`: Absolute file path

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Fro-Q/headup.nvim",
  config = function()
    require("headup").setup({
      -- your configuration here
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Fro-Q/headup.nvim",
  config = function()
    require("headup").setup({
      -- your configuration here
    })
  end
}
```

## Configuration

headup.nvim uses a simplified configuration format where you pass global settings and configuration items directly in the setup table, without needing a `configs` wrapper key.

### Basic Structure

```lua
require("headup").setup({
  -- Global settings
  enabled = true,
  silent = true,
  
  -- Configuration items (array elements)
  {
    pattern = "*.md",          -- file name glob(s) for autocmd
    match_pattern = "...",     -- Lua pattern to capture value in file content
    content = "current_time",  -- what to write
    -- other options...
  },
  {
    pattern = {"*.py", "*.pyi"},
    match_pattern = "...",
    content = "current_time",
    -- other options...
  },
  -- Add more configuration items as needed...
})
```

### Default Configuration

```lua
require("headup").setup({
  enabled = true,
  silent = true, -- Set to false to show notifications when updating

  -- Global fallbacks (used when an item doesn't set its own value)
  time_format = "inherit",
  max_lines = 20,
  end_pattern = "^---%s*$", -- Stop scanning at end of YAML front matter
  -- exclude_pattern = "*/archive/*", -- optional global exclude

  {
    pattern = "*.md",
    match_pattern = "last_modified:%s*(.-)%s*$",
    content = "current_time",
    -- This item will use the global fallbacks above
  },
})
```

### Configuration Options

#### Global Options
- `enabled` (boolean): Whether the plugin is enabled globally (default: `true`)
- `silent` (boolean): Whether to suppress notification messages (default: `true`)
- `time_format` (string|"inherit"): Global fallback for time format when `content = "current_time"`
- `max_lines` (number): Global fallback for maximum number of lines to scan from the beginning
- `end_pattern` (string): Global fallback Lua pattern; stop scanning when matched (prevents over-scanning)
- `exclude_pattern` (string|string[]): Global fallback filename glob(s) to exclude from processing

#### Per-Config Options (as array items)
Each configuration item should be a table with the following fields:
- `pattern` (string|string[]): File name glob(s) for autocmd (e.g., `"*.md"` or `{ "*.md", "*.markdown" }`)
- `match_pattern` (string): Lua pattern to capture the content to update
- `content` (string): What to write (`"current_time"`, `"file_size"`, `"line_count"`, `"file_name"`, `"file_path"`, `"file_path_abs"`)
- `time_format` (string): Time format string for `current_time`, use `"inherit"` to keep original format
- `max_lines` (number): Maximum number of lines to search from the beginning (default: 20)
- `end_pattern` (string, optional): Lua pattern that, when matched, stops scanning further lines (prevents over-scanning)
- `exclude_pattern` (string|string[], optional): File name glob(s) to exclude from processing

Note: For `time_format`, `max_lines`, `end_pattern`, and `exclude_pattern`, if an item doesn't provide a value, it will fall back to the corresponding global value when set.

### Example Configurations

#### Markdown with YAML Front Matter

```lua
{
  pattern = "*.md",
  match_pattern = "last_modified:%s*(.-)%s*$",
  content = "current_time",
  time_format = "inherit",
  max_lines = 20,
  end_pattern = "^---%s*$",
}
```

#### Multiple File Types with Different Patterns

```lua
require("headup").setup({
  enabled = true,
  silent = false, -- Show notifications
  
  -- Markdown files
  {
    pattern = {"*.md", "*.markdown"},
    match_pattern = "last_modified:%s*(.-)%s*$",
    content = "current_time",
    time_format = "%Y-%m-%d %H:%M:%S",
    max_lines = 20,
  end_pattern = "^---%s*$",
    exclude_pattern = "*/archive/*", -- skip archived notes
  },
  
  -- Text files with file size
  {
    pattern = "*.txt",
    match_pattern = "Size:%s*(.-)%s*$",
    content = "file_size",
    max_lines = 10,
  },
  
  -- Any file type with line count
  {
    pattern = "*",
    match_pattern = "Lines:%s*(.-)%s*$",
    content = "line_count",
    max_lines = 15,
  },
})
```

## Commands

- `:HeadupEnable` / `:HeadupDisable` / `:HeadupToggle` — control plugin state
- `:HeadupUpdate` — manually update current buffer
- `:HeadupClearCache` — clear internal cache
- `:HeadupShowConfig` — show current effective configuration (formatted table)

The plugin provides the following commands:

- `:HeadupEnable` - Enable the plugin
- `:HeadupDisable` - Disable the plugin  
- `:HeadupToggle` - Toggle plugin on/off
- `:HeadupUpdate` - Manually update metadata in current buffer
- `:HeadupClearCache` - Clear internal cache

## How It Works

1. **File Loading**: When a file is opened, the plugin scans for patterns and caches the matched content
2. **Content Detection**: On save, it checks if the file content has actually changed
3. **Manual Edit Respect**: If you manually edited the metadata, the plugin won't overwrite it
4. **Smart Update**: Only updates metadata when file content changed but metadata wasn't manually modified
5. **Cache Update**: Updates the internal cache after successful updates

## Example Usage

For a Markdown file with YAML front matter:

```markdown
---
title: My Document
last_modified: 2024-01-01 12:00:00
---

# My Document

Content here...
```

When you edit and save the file, `last_modified` will automatically update to the current timestamp while preserving the original time format.

## Silent Mode

By default, the plugin operates silently. To see notifications when metadata is updated, set `silent = false` in your configuration:

```lua
require("headup").setup({
  silent = false, -- Show notifications
  -- other config...
})
```

When `silent = false`, you'll see notifications like:
- "headup.nvim: Auto-updated timestamp to: 2024-11-02 15:30:45"
- "headup.nvim: Updated file size to: 2.1 KB"

## License

MIT License - see [LICENSE](LICENSE) file for details.
