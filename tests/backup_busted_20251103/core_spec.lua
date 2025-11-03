-- Backup of previous busted-style tests for core
---@diagnostic disable: undefined-global, undefined-field
local Core = require('headup.core')
local Config = require('headup.config')

before_each(function()
  -- Reset to defaults for each test
  Config.setup()
  Core.setup(Config.get())
end)

describe("headup setup", function()
  it("should use default configuration", function()
    local cfg = Config.get()
    assert.True(cfg.enabled)
    assert.True(cfg.silent)
    assert.True(#cfg.configs >= 1)
  end)

  it("should accept custom configuration", function()
    Config.setup({
      silent = false,
      {
        pattern = "*.md",
        match_pattern = "date:%s*(.-)%s$",
        content = "current_time",
        time_format = "inherit",
        max_lines = 10,
        end_pattern = "^---%s$",
      }
    })
    Core.setup(Config.get())

    local cfg = Config.get()
    assert.False(cfg.silent)
    assert.True(#cfg.configs >= 1)
  end)
end)

describe("headup control", function()
  it("should enable when disabled", function()
    Config.setup({ enabled = false })
    Core.setup(Config.get())
    assert.False(Config.get().enabled)

    Config.set_enabled(true)
    Core.enable()
    assert.True(Config.get().enabled)
  end)

  it("should disable when enabled", function()
    Config.setup({ enabled = true })
    Core.setup(Config.get())
    assert.True(Config.get().enabled)

    Config.set_enabled(false)
    Core.disable()
    assert.False(Config.get().enabled)
  end)

  it("should toggle state correctly", function()
    Config.setup({ enabled = true })
    Core.setup(Config.get())
    local initial_state = Config.get().enabled

    local function toggle()
      local state = Config.is_enabled()
      Config.set_enabled(not state)
      if not state then
        Core.enable()
      else
        Core.disable()
      end
    end

    toggle()
    assert.are_not.equal(Config.get().enabled, initial_state)

    toggle()
    assert.are.equal(Config.get().enabled, initial_state)
  end)
end)
