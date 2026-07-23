-- editor.lua —— 编辑增强
return {
  -- 注释切换（gcc 当前行 / gc{motion}，替代 NERD_commenter）
  { 'numToStr/Comment.nvim', opts = {}, lazy = false },

  -- 增删改包围符 cs"' / ds" / ysiw"
  { 'kylechui/nvim-surround', event = 'VeryLazy', opts = {} },

  -- 对齐（替代 vim-easy-align）：选中后 gaip=
  { 'echasnovski/mini.align', version = false, opts = {} },

  -- . 重复增强（让插件操作也能用 . 重复）
  { 'tpope/vim-repeat', event = 'VeryLazy' },

  -- 会话恢复（配合 tmux 重连）
  { 'folke/persistence.nvim', event = 'BufReadPre', opts = {} },

  -- 光标多光标编辑 <C-n> 选中下一个相同词
  { 'mg979/vim-visual-multi', event = 'VeryLazy' },
}
