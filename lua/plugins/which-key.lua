-- lua/plugins/which-key.lua
return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- 关掉所有图标（nerd font / group 图标都不显示）
		icons = {
			enabled = false,
		},
		window = {
			layout = {
				width = { min = 20, max = 60 },
				height = { min = 4, max = 25 },
				spacing = 3,
			},
		},
	},
	config = function(_, opts)
		local wk = require("which-key")
		wk.setup(opts)

		-- 只声明「分组前缀」，单键 action（<leader>/ 和 <leader><tab>）不在此声明
		wk.add({
			{ "<leader>b", group = "Buffer" },
			{ "<leader>c", group = "Code" },
			{ "<leader>d", group = "Debug" },
			{ "<leader>f", group = "File/Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>j", group = "Jump" },
			{ "<leader>o", group = "OpenCode" },
			{ "<leader>q", group = "Quit/Session" },
		})
	end,
}
