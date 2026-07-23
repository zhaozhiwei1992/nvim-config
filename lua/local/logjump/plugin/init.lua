-- logjump/plugin/init.lua —— 命令 + 键位注册（插件加载时自动 source）
local M = require('logjump')

vim.api.nvim_create_user_command('LogJump', function(opts)
  M.jump_buffer(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '?',
  desc = '解析当前 buffer 中的堆栈跟踪，填充 quickfix（可选指定搜索目录）',
  complete = 'dir',
})

vim.api.nvim_create_user_command('LogJumpLine', function(opts)
  M.jump_line(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '?',
  desc = '跳转当前行的堆栈跟踪（可选指定搜索目录）',
  complete = 'dir',
})

-- 键位：<leader>j 前缀 = jump
vim.keymap.set('n', '<leader>jl', function() M.jump_line() end, { desc = 'logjump: 跳转当前行' })
vim.keymap.set('n', '<leader>jj', function() M.jump_buffer() end, { desc = 'logjump: 解析整个buffer' })
vim.keymap.set('v', '<leader>js', function() M.jump_selection() end, { desc = 'logjump: 解析选区' })
