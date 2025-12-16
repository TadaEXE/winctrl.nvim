if vim.g.loaded_winctrl == 1 then
	return
end
vim.g.loaded_winctrl = 1

vim.api.nvim_create_user_command("WinCtrl", function()
	require("winctrl").start()
end, {})
