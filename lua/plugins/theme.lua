-- theme.lua —— 配色 + statusline
return {
	-- 1) darkman 监听（只负责发事件，不自动切 colorscheme）
	{
		"4e554c4c/darkman.nvim",
		event = "VimEnter",
		build = "go build -o bin/darkman.nvim",
		opts = {
			change_background = false,
			send_user_event = true,
		},
		config = function(_, opts)
			require("darkman").setup(opts)

			local function apply_tokyonight(mode)
				if mode == "dark" then
					require("tokyonight").setup({ style = "night", transparent = false })
					vim.opt.background = "dark"
				else
					require("tokyonight").setup({ style = "day", transparent = false })
					vim.opt.background = "light"
				end
				-- 关键：先 setup 再 colorscheme，顺序不能反
				vim.cmd.colorscheme("tokyonight")
			end

			-- 监听 darkman 事件（两种事件名都兼容）
			vim.api.nvim_create_autocmd("User", {
				pattern = { "DarkMode", "DarkmanDark" },
				callback = function()
					apply_tokyonight("dark")
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				pattern = { "LightMode", "DarkmanLight" },
				callback = function()
					apply_tokyonight("light")
				end,
			})

			-- 启动时手动触发一次（darkman.nvim 不会在加载时自动触发）
			local obj = vim.system({ "darkman", "get" }, { text = true }):wait()
			local mode = (obj.code == 0 and obj.stdout and vim.trim(obj.stdout) == "light") and "light" or "dark"
			apply_tokyonight(mode)
		end,
	},
	-- 配色（priority 高确保最先加载, tokyonight 本体（只 setup，不在这里 colorscheme, 通过上边的darkman来根据系统状态动态切换）
	{
		"folke/tokyonight.nvim",
		priority = 1000,
		lazy = false,
		opts = { style = "night", transparent = false },
		config = function(_, opts)
			require("tokyonight").setup(opts)
			vim.cmd.colorscheme("tokyonight")
		end,
	},

	-- statusline（替代 vim-airline）
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = { options = { theme = "tokyonight" } },
	},

	-- buffer 标签栏（替代 bufexplorer 的切缓冲区体验）
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		version = "*",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = { options = { diagnostics = "nvim_lsp" } },
	},
}
