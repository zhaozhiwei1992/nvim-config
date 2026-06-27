-- dap.lua —— 调试 DAP
return {
  { 'mfussenegger/nvim-dap', event = 'VeryLazy' },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    opts = {},
  },
  { 'theHamsta/nvim-dap-virtual-text', opts = {} }, -- 内联显示变量
  {
    'jay-babu/mason-nvim-dap.nvim',
    opts = {
      ensure_installed = { 'delve', 'codelldb', 'python' },
      automatic_installation = true,
    },
  },
}

-- 通用 DAP 键位（放 keymaps 或此处）
-- <leader>db 切断点 | <leader>dc 继续 | <leader>di 步入 | <leader>do 步出 | <leader>du 开 UI
