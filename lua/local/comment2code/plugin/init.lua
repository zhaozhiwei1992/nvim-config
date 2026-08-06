-- comment2code/plugin/init.lua —— 命令 + 键位注册（插件加载时自动 source）
local M = require('comment2code')

vim.api.nvim_create_user_command('AI', function()
  M.generate()
end, { desc = 'comment2code: @ai 注释下生成代码' })

vim.api.nvim_create_user_command('AIRegenerate', function()
  M.regenerate()
end, { desc = 'comment2code: 用上次 prompt 重新生成' })

vim.api.nvim_create_user_command('AIClear', function()
  M.clear()
end, { desc = 'comment2code: 撤销上次插入的代码' })

vim.api.nvim_create_user_command('AIPrompt', function()
  M.show_prompt()
end, { desc = 'comment2code: 查看上次 prompt' })

-- 键位：<leader>a 前缀 = ai 生成
vim.keymap.set('n', '<leader>ai', function()
  M.generate()
end, { desc = 'comment2code: 生成代码' })
vim.keymap.set('v', '<leader>ai', function()
  M.generate_visual()
end, { desc = 'comment2code: 选区生成代码' })
vim.keymap.set('n', '<leader>ar', function()
  M.regenerate()
end, { desc = 'comment2code: 重新生成' })
vim.keymap.set('n', '<leader>ac', function()
  M.clear()
end, { desc = 'comment2code: 撤销上次插入' })
vim.keymap.set('n', '<leader>at', function()
  M.show_prompt()
end, { desc = 'comment2code: 查看上次 prompt' })
