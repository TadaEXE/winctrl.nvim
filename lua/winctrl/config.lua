local M = {}

---@class WinCtrlSymbolsConfig
---@field up? string
---@field down? string
---@field left? string
---@field right? string

---@class WinCtrlKeysConfig
---@field left? string
---@field right? string
---@field up? string
---@field down? string
---@field quit? string
---@field esc? string

---@class WinCtrlConfig
---@field step integer
---@field border? string|table
---@field symbols WinCtrlSymbolsConfig
---@field keys WinCtrlKeysConfig
---@field notify boolean

---@type WinCtrlConfig
M.defaults = {
	step = 4,
	border = "single",
	symbols = { up = "▲", down = "▼", left = "◀", right = "▶" },
	keys = {
		left = "h",
		right = "l",
		up = "k",
		down = "j",
		quit = "q",
		esc = "<Esc>",
	},
	notify = true,
}

---@param dst table
---@param src table|nil
---@return table
local function deep_merge(dst, src)
	for k, v in pairs(src or {}) do
		if type(v) == "table" and type(dst[k]) == "table" then
			deep_merge(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

---@param user WinCtrlConfig|table|nil
---@return WinCtrlConfig
function M.resolve(user)
	---@type WinCtrlConfig
	local cfg = vim.deepcopy(M.defaults)
	deep_merge(cfg, user)
	return cfg
end

---@param cfg WinCtrlConfig
function M.validate(cfg)
	if type(cfg.step) ~= "number" then
		error("winctrl: step must be a number")
	end

	if cfg.border ~= nil then
		local t = type(cfg.border)
		if t ~= "string" and t ~= "table" then
			error("winctrl: float.border must be a string or table")
		end
	end

	if cfg.keys then
		for k, v in pairs(cfg.keys) do
			if type(v) ~= "string" then
				error("winctrl: keys." .. tostring(k) .. " must be a string")
			end
		end
	end

	if cfg.symbols then
		for k, v in pairs(cfg.symbols) do
			if type(v) ~= "string" then
				error("winctrl: symbols." .. tostring(k) .. " must be a string")
			end
		end
	end

	if type(cfg.notify) ~= "boolean" then
		error("winctrl: notify must be boolean")
	end
end

return M
