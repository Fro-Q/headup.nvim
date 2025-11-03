-- mini.test version of core tests
local MiniTest = require('mini.test')
local Headup = require('headup')

local T = MiniTest.new_set()

T["setup uses default configuration"] = function()
  Headup.setup()
  local cfg = Headup.get_config()
  assert(cfg.enabled == true)
  assert(cfg.silent == true)
  assert(#cfg.configs >= 1)
end

T["setup accepts custom configuration"] = function()
  Headup.setup({
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
  local cfg = Headup.get_config()
  assert(cfg.silent == false)
  assert(#cfg.configs >= 1)
end

T["control: enable when disabled"] = function()
  Headup.setup({ enabled = false })
  assert(Headup.get_config().enabled == false)

  Headup.enable()
  assert(Headup.get_config().enabled == true)
end

T["control: disable when enabled"] = function()
  Headup.setup({ enabled = true })
  assert(Headup.get_config().enabled == true)

  Headup.disable()
  assert(Headup.get_config().enabled == false)
end

T["control: toggle state correctly"] = function()
  Headup.setup({ enabled = true })
  local initial_state = Headup.get_config().enabled

  local function toggle()
    if Headup.get_config().enabled then Headup.disable() else Headup.enable() end
  end

  toggle()
  assert(Headup.get_config().enabled == (not initial_state))

  toggle()
  assert(Headup.get_config().enabled == initial_state)
end

return T
