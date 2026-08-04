-- clipboard-path/plugin/init.lua —— 命令 + 键位注册（lazy 加载该插件时 source）
local M = require('clipboard-path')

-- 命令形式：:CopyPath abs|rel|dir|name|line
local subcmds = {
  abs = { fn = M.abs_path,  label = '文件绝对路径' },
  rel = { fn = M.rel_path,  label = '文件相对路径' },
  dir = { fn = M.dir,       label = '所在目录' },
  name = { fn = M.filename, label = '文件名' },
  line = { fn = M.line_ref, label = '文件:行号' },
}
vim.api.nvim_create_user_command('CopyPath', function(opts)
  local sub = opts.fargs[1] or 'abs'
  local entry = subcmds[sub] or subcmds.abs
  M.copy(entry.fn(), entry.label)
end, {
  nargs = '?',
  complete = function() return vim.tbl_keys(subcmds) end,
  desc = '复制当前文件路径到剪贴板 [abs|rel|dir|name|line]',
})

-- 键位：<leader>y 前缀 = yank path
local map = vim.keymap.set
map('n', '<leader>yf', function() M.copy(M.abs_path(),  '文件绝对路径') end, { desc = '复制文件绝对路径' })
map('n', '<leader>yr', function() M.copy(M.rel_path(),  '文件相对路径') end, { desc = '复制文件相对路径' })
map('n', '<leader>yd', function() M.copy(M.dir(),       '所在目录')    end, { desc = '复制文件所在目录' })
map('n', '<leader>yn', function() M.copy(M.filename(), '文件名')      end, { desc = '复制文件名' })
map('n', '<leader>yl', function() M.copy(M.line_ref(), '文件:行号')    end, { desc = '复制 file:line' })