local config_mod = require("winctrl.config")
local core = require("winctrl.core")

local M = {}

---@class WinCtrlModuleState
---@field configured boolean
---@field config WinCtrlConfig|nil
local state = {
	configured = false,
	config = nil,
}

---@param user_config WinCtrlConfig|table|nil
function M.setup(user_config)
	local cfg = config_mod.resolve(user_config)
	config_mod.validate(cfg)

	state.config = cfg
	state.configured = true

	core.set_config(cfg)
end

---@param opts WinCtrlStartOpts|nil
function M.start(opts)
	if not state.configured then
		M.setup()
	end
	core.start(opts)
end

function M.stop()
	core.stop()
end

---@return WinCtrlConfig|nil
function M.config()
	return state.config
end

return M
