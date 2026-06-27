-- lsp.lua —— LSP 配置（nvim 0.12 原生 API：vim.lsp.config / vim.lsp.enable）
-- 关键：不再需要 nvim-lspconfig 的 setup()，各 server 配置放 ~/.config/nvim/lsp/<name>.lua
local lang = require('config.lang')

return {
  -- mason：管理 LSP/格式化/DAP 二进制
  { 'williamboman/mason.nvim', cmd = 'Mason', build = ':MasonUpdate', opts = {} },

  -- mason-tool-installer：自动安装各语言工具
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    event = 'VeryLazy',
    opts = {
      ensure_installed = lang.mason_tools,
      auto_update = true,
    },
  },

  -- LSP 核心配置 + 诊断 + keymap
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'williamboman/mason.nvim', 'saghen/blink.cmp' },
    config = function()
      -- 诊断显示
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
      })

      -- 进 LSP 时绑一组通用键位
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = 'LSP: ' .. desc })
          end
          map('n', 'gd', vim.lsp.buf.definition, '跳转定义')
          map('n', 'gr', vim.lsp.buf.references, '引用')
          map('n', 'gD', vim.lsp.buf.declaration, '声明')
          map('n', 'gi', vim.lsp.buf.implementation, '实现')
          map('n', 'K', vim.lsp.buf.hover, '悬停文档')
          map('n', '<leader>ca', vim.lsp.buf.code_action, '代码操作')
          map('n', '<leader>cr', vim.lsp.buf.rename, '重命名')
          map('n', '<leader>cd', vim.diagnostic.open_float, '行诊断')
          map('n', '[d', vim.diagnostic.goto_prev, '上一条诊断')
          map('n', ']d', vim.diagnostic.goto_next, '下一条诊断')
        end,
      })

      -- 用 0.12 原生 API 启用各语言服务器（配置见 lsp/<name>.lua）
      for _, name in ipairs(lang.servers) do
        vim.lsp.enable(name)
      end
    end,
  },

  -- LSP 进度/UI 美化
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
}
