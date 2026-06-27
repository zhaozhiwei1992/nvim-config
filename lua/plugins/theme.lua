-- theme.lua —— 配色 + statusline
return {
  -- 配色（priority 高确保最先加载）
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    lazy = false,
    opts = { style = 'night', transparent = false },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme('tokyonight')
    end,
  },

  -- statusline（替代 vim-airline）
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { options = { theme = 'tokyonight' } },
  },

  -- buffer 标签栏（替代 bufexplorer 的切缓冲区体验）
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    version = '*',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { options = { diagnostics = 'nvim_lsp' } },
  },
}
