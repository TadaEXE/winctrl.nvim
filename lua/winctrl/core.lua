local M = {}

---@class WinCtrlRect
---@field top integer
---@field left integer
---@field bottom integer
---@field right integer
---@field width integer
---@field height integer

---@class WinCtrlHint
---@field text string
---@field row integer
---@field col integer

---@class WinCtrlState
---@field active boolean
---@field floats integer[]
---@field buf integer|nil
---@field mapped_keys string[]
---@field step integer
---@field autocmd_id integer|nil
local state = {
	active = false,
	floats = {},
	buf = nil,
	mapped_keys = {},
	step = 4,
	autocmd_id = nil,
}

---@type WinCtrlConfig|nil
local cfg = nil

---@param v integer
---@param min integer
---@param max integer
---@return integer
local function clamp(v, min, max)
	if v < min then
		return min
	end
	if v > max then
		return max
	end
	return v
end

local function clear_floats()
	for _, win in ipairs(state.floats) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	state.floats = {}
end

---@param win integer
---@return WinCtrlRect
local function get_win_rect(win)
	local pos = vim.fn.win_screenpos(win)
	local top = pos[1] - 1
	local left = pos[2] - 1
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)
	return {
		top = top,
		left = left,
		bottom = top + height - 1,
		right = left + width - 1,
		width = width,
		height = height,
	}
end

---@param cur integer
---@param side '"left"'|'"right"'
---@return integer|nil
local function nearest_adjacent_win_h(cur, side)
  local cur_rect = get_win_rect(cur)

  local best_win = nil
  local best_dist = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= cur then
      local wcfg = vim.api.nvim_win_get_config(win)
      if wcfg.relative == "" then
        local r = get_win_rect(win)

        local vertical_overlap = not (r.bottom < cur_rect.top or r.top > cur_rect.bottom)
        if vertical_overlap then
          if side == "right" and r.left > cur_rect.right then
            local dist = r.left - cur_rect.right
            if best_dist == nil or dist < best_dist then
              best_dist = dist
              best_win = win
            end
          elseif side == "left" and r.right < cur_rect.left then
            local dist = cur_rect.left - r.right
            if best_dist == nil or dist < best_dist then
              best_dist = dist
              best_win = win
            end
          end
        end
      end
    end
  end

  return best_win
end

---@param cur integer
---@param side '"up"'|'"down"'
---@return integer|nil
local function nearest_adjacent_win_v(cur, side)
  local cur_rect = get_win_rect(cur)

  local best_win = nil
  local best_dist = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= cur then
      local wcfg = vim.api.nvim_win_get_config(win)
      if wcfg.relative == "" then
        local r = get_win_rect(win)

        local horizontal_overlap = not (r.right < cur_rect.left or r.left > cur_rect.right)
        if horizontal_overlap then
          if side == "down" and r.top > cur_rect.bottom then
            local dist = r.top - cur_rect.bottom
            if best_dist == nil or dist < best_dist then
              best_dist = dist
              best_win = win
            end
          elseif side == "up" and r.bottom < cur_rect.top then
            local dist = cur_rect.top - r.bottom
            if best_dist == nil or dist < best_dist then
              best_dist = dist
              best_win = win
            end
          end
        end
      end
    end
  end

  return best_win
end

---@return boolean, boolean, boolean, boolean
local function compute_neighbors()
  local cur = vim.api.nvim_get_current_win()
  local cfg_cur = vim.api.nvim_win_get_config(cur)
  if cfg_cur.relative ~= "" then
    return false, false, false, false
  end

  local left_win = nearest_adjacent_win_h(cur, "left")
  local right_win = nearest_adjacent_win_h(cur, "right")

  local can_left = false
  local can_right = false

  if left_win and vim.api.nvim_win_is_valid(left_win) then
    can_left = not vim.wo[left_win].winfixwidth
  end

  if right_win and vim.api.nvim_win_is_valid(right_win) then
    can_right = not vim.wo[right_win].winfixwidth
  end

  local can_up = false
  local can_down = false

  local up_win = nearest_adjacent_win_v(cur, "up")
  local down_win = nearest_adjacent_win_v(cur, "down")

  if up_win and vim.api.nvim_win_is_valid(up_win) then
    can_up = not vim.wo[up_win].winfixheight
  end

  if down_win and vim.api.nvim_win_is_valid(down_win) then
    can_down = not vim.wo[down_win].winfixheight
  end

  return can_left, can_right, can_up, can_down
end

local function show_floats()
	if not state.active then
		return
	end

	clear_floats()

	local win = vim.api.nvim_get_current_win()
	local rect = get_win_rect(win)
	local lines = vim.o.lines
	local cols = vim.o.columns

	local has_left, has_right, has_up, has_down = compute_neighbors()

	local c = cfg or require("winctrl").config() or {}
	local sym = c.symbols or {}
	local up_text = sym.up or "∧"
	local down_text = sym.down or "v"
	local left_text = sym.left or "<"
	local right_text = sym.right or ">"

	---@type WinCtrlHint[]
	local hints = {}

	if has_up or has_down then
		local center_col = rect.left + math.floor((rect.width - 1) / 2)

		if has_up then
			table.insert(hints, { text = up_text, row = rect.top - 4, col = center_col })
			table.insert(hints, { text = down_text, row = rect.top, col = center_col })
		end

		if has_down then
			table.insert(hints, { text = up_text, row = rect.bottom - 2, col = center_col })
			table.insert(hints, { text = down_text, row = rect.bottom + 2, col = center_col })
		end
	end

	if has_left or has_right then
		local center_row = rect.top + math.floor(rect.height / 2)

		if has_left and not has_right then
			local border_col = rect.left - 2
			table.insert(hints, { text = left_text, row = center_row, col = border_col - 2 })
			table.insert(hints, { text = right_text, row = center_row, col = border_col + 2 })
		elseif has_right and not has_left then
			local border_col = rect.right
			table.insert(hints, { text = left_text, row = center_row, col = border_col - 2 })
			table.insert(hints, { text = right_text, row = center_row, col = border_col + 2 })
		elseif has_left and has_right then
			local right_col = rect.right
			table.insert(hints, { text = left_text, row = center_row, col = right_col - 2 })
			table.insert(hints, { text = right_text, row = center_row, col = right_col + 2 })
		end
	end

	local border = c.border or "single"

	for _, h in ipairs(hints) do
		local row = clamp(h.row, 0, lines - 2)
		local col = clamp(h.col, 0, math.max(cols - #h.text - 1, 0))

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { h.text })

		local winid = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = row,
			col = col,
			width = 1,
			height = 1,
			style = "minimal",
			border = border,
			focusable = false,
			noautocmd = true,
			zindex = 200,
		})

		table.insert(state.floats, winid)
	end
end

---@param direction integer
function M.resize_width(direction)
	if not state.active or direction == 0 then
		return
	end

	local has_left, has_right = compute_neighbors()
	if not has_left and not has_right then
		return
	end

	local sign
	if has_left and not has_right then
		sign = (direction < 0) and 1 or -1
	elseif has_right and not has_left then
		sign = (direction < 0) and -1 or 1
	else
		sign = (direction < 0) and -1 or 1
	end

	local delta = sign * state.step
	local cmd = (delta > 0) and ("vertical resize +" .. delta) or ("vertical resize " .. delta)
	vim.cmd(cmd)
	show_floats()
end

---@param direction integer
function M.resize_height(direction)
	if not state.active or direction == 0 then
		return
	end

	local _, _, has_up, has_down = compute_neighbors()
	if not has_up and not has_down then
		return
	end

	local sign
	if has_up and not has_down then
		sign = (direction < 0) and 1 or -1
	elseif has_down and not has_up then
		sign = (direction < 0) and -1 or 1
	else
		sign = (direction < 0) and -1 or 1
	end

	local delta = sign * state.step
	local cmd = (delta > 0) and ("resize +" .. delta) or ("resize " .. delta)
	vim.cmd(cmd)
	show_floats()
end

function M.stop()
	if not state.active then
		return
	end

	clear_floats()

	if state.autocmd_id then
		pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
		state.autocmd_id = nil
	end

	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		for _, lhs in ipairs(state.mapped_keys or {}) do
			pcall(vim.keymap.del, "n", lhs, { buffer = state.buf })
		end
	end

	state.mapped_keys = {}
	state.active = false
	state.buf = nil
end

---@class WinCtrlStartOpts
---@field step? integer

---@param opts WinCtrlStartOpts|nil
function M.start(opts)
	if state.active then
		return
	end

	opts = opts or {}
	local c = cfg or require("winctrl").config() or {}
	local keys = c.keys or {}

	state.step = (type(opts.step) == "number" and opts.step) or (c.step or 4)

	state.active = true
	state.buf = vim.api.nvim_get_current_buf()
	state.mapped_keys = {}

	local function map(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, {
			buffer = state.buf,
			silent = true,
			nowait = true,
		})
		table.insert(state.mapped_keys, lhs)
	end

	map(keys.left or "h", function()
		M.resize_width(-1)
	end)
	map(keys.right or "l", function()
		M.resize_width(1)
	end)
	map(keys.up or "k", function()
		M.resize_height(-1)
	end)
	map(keys.down or "j", function()
		M.resize_height(1)
	end)
	map(keys.quit or "q", M.stop)
	map(keys.esc or "<Esc>", M.stop)

	local group = vim.api.nvim_create_augroup("WinCtrlResizeHints", { clear = false })

	state.autocmd_id = vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "InsertEnter" }, {
		group = group,
		buffer = state.buf,
		callback = function()
			if state.active then
				M.stop()
			end
		end,
	})

	show_floats()

	if c.notify and vim.notify then
		vim.notify(
			string.format(
				"Resize mode: %s/%s/%s/%s resize, %s or %s to exit",
				keys.left or "h",
				keys.down or "j",
				keys.up or "k",
				keys.right or "l",
				keys.quit or "q",
				keys.esc or "<Esc>"
			),
			vim.log.levels.INFO
		)
	end
end

---@param c WinCtrlConfig
function M.set_config(c)
	cfg = c
end

return M
