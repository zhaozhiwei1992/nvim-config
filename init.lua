-- init.lua —— 唯一入口
-- 设 leader 必须在任何插件加载之前
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

-- 关键路径常量（后面各模块复用）
vim.g.data = vim.fn.stdpath('data') -- ~/.local/share/nvim
vim.g.state = vim.fn.stdpath('state') -- ~/.local/state/nvim

-- 把 mason 二进制目录注入 PATH：lsp/<name>.lua 的 cmd、conform 的 formatter 都靠它找可执行文件
-- 必须放在插件加载前（LSP attach / formatter 解析时 PATH 已含 mason bin）
vim.env.PATH = vim.fs.normalize(vim.g.data .. '/mason/bin') .. ':' .. vim.env.PATH

-- 加载各模块（顺序敏感）
require('config.options')
require('config.keymaps')
require('config.autocmds')
require('config.lazy')
