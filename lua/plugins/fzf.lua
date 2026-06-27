-- fzf.lua —— 模糊检索（复用本机 fzf/rg/fd）
return {
  {
    'ibhagwan/fzf-lua',
    event = 'VeryLazy',
    -- <leader>f 系列检索；<leader>s 系列符号检索
    keys = {
      { '<leader>ff', '<cmd>FzfLua files<CR>', desc = '找文件' },
      { '<leader>fg', '<cmd>FzfLua live_grep<CR>', desc = '全局内容' },
      { '<leader>fb', '<cmd>FzfLua buffers<CR>', desc = '切缓冲区' },
      { '<leader>fh', '<cmd>FzfLua helptags<CR>', desc = '帮助' },
      { '<leader>fr', '<cmd>FzfLua oldfiles<CR>', desc = '最近文件' },
      { '<leader>fs', '<cmd>FzfLua lsp_live_workspace_symbols<CR>', desc = '工作区符号' },
      { '<leader>fd', '<cmd>FzfLua diagnostics_document<CR>', desc = '文档诊断' },
    },
    opts = {},
  },
}
