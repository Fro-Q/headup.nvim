--- *headup.nvim*
---
--- A Neovim plugin that automatically updates file header metadata when files
--- are saved.
---
--- MIT License Copyright (c) 2025 Fro-Q

---@toc

--- Features ~
--- - Automatic Updates: Automatically updates metadata in file headers when saving
--- - Respects Manual Edits: Won't overwrite user manual changes to metadata
--- - Configurable: Support multiple file types with different patterns
---
--- Supported Content ~
--- - `current_time`: Current timestamp
--- - `file_size`: File size with automatic unit conversion (B, KB, MB, GB, TB)
--- - `line_count`: Number of lines in the file
--- - `file_name`: The base filename of the buffer
--- - `file_path`: File path relative to current working directory
--- - `file_path_abs`: Absolute file path
---@tag Headup.intro

---@toc_entry

