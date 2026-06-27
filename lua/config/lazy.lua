-- lazy.lua —— lazy.nvim 引导 + 插件 spec 汇总
-- bootstrap：首次运行自动克隆 lazy.nvim
local lazypath = vim.g.data .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 加载 lua/plugins/*.lua 的所有 spec
require('lazy').setup('plugins', {
  -- 自动检查更新（每天一次）
  checker = { enabled = true, frequency = 86400 },
  -- 关闭默认 vim 自带一些不用的插件，加速启动
  performance = {
    rtp = {
      disabled_plugins = { 'netrwPlugin', 'tohtml', 'tutor' },
    },
  },
  install = { colorscheme = { 'tokyonight' } },
})
