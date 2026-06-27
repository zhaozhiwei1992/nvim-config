-- init.lua —— 唯一入口
-- 设 leader 必须在任何插件加载之前
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

-- 关键路径常量（后面各模块复用）
vim.g.data = vim.fn.stdpath('data') -- ~/.local/share/nvim
vim.g.state = vim.fn.stdpath('state') -- ~/.local/state/nvim

-- 加载各模块（顺序敏感）
require('config.options')
require('config.keymaps')
require('config.autocmds')
require('config.lazy')
