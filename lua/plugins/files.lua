-- files.lua —— 文件导航（替代 NERDTree）
return {
  -- 文件树
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    keys = {
      { '<F5>', '<cmd>Neotree toggle<CR>', desc = '文件树' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      filesystem = {
        window = { width = 30 },
        follow_current_file = { enabled = true },
      },
    },
  },

  -- 目录式编辑（用 - 进入）
  {
    'stevearc/oil.nvim',
    opts = {},
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = { { '-', '<cmd>Oil<CR>', desc = '浏览目录(oil)' } },
  },

  -- 符号大纲（替代 Tagbar）
  {
    'stevearc/aerial.nvim',
    keys = { { '<F6>', '<cmd>AerialToggle!<CR>', desc = '符号大纲' } },
    opts = {},
  },
}
