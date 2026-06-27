-- git.lua —— git 操作（magit/forge 留 emacs，nvim 只用轻量方案）
return {
  -- git 行内标记 / hunk 操作
  { 'lewis6991/gitsigns.nvim', event = 'BufReadPre', opts = {} },

  -- lazygit 外挂 TUI：提交/分支/rebase 快捷
  -- cond 守卫：仅当系统装了 lazygit 二进制才启用，否则 <leader>gg 不注册，干净降级
  -- 装法：yay -S lazygit
  {
    'kdheepak/lazygit.nvim',
    cond = vim.fn.executable('lazygit') == 1,
    cmd = 'LazyGit',
    keys = { { '<leader>gg', '<cmd>LazyGit<CR>', desc = 'lazygit' } },
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
}
