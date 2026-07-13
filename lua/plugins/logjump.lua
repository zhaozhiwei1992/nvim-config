-- logjump.lua —— 日志堆栈跳转（lazy.nvim spec 包装）
-- 实际逻辑在 lua/local/logjump.lua 模块中，本文件负责注册命令和键位。

-- 引入模块
local M = require('lib.logjump')

-- 文件级别创建用户命令（spec 文件被 lazy.nvim require 时即执行）
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

return {
  {
    -- 本地插件：dir 指向 nvim 配置目录，lazy 把它当作一个本地 spec 加载
    dir = vim.fn.stdpath('config'),
    name = 'logjump',
    lazy = false,

    -- 键位：<leader>j 前缀 = jump（闭包引用 M，不依赖 _G 全局）
    keys = {
      { '<leader>jl', function() M.jump_line() end,          desc = 'logjump: 跳转当前行' },
      { '<leader>jj', function() M.jump_buffer() end,        desc = 'logjump: 解析整个buffer' },
      { '<leader>js', function() M.jump_selection() end, mode = 'v', desc = 'logjump: 解析选区' },
    },
  },
}
