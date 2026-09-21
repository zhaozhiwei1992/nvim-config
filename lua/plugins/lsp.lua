-- lsp.lua —— LSP 配置（Java 编辑器版，2026-09-21）
-- 链：mason 装 jdtls/google-java-format（清单见 config/lang.lua）
--   → nvim-jdtls 在 ft=java 时启动（配置全在 ftplugin/java.lua，不经 vim.lsp.enable）
-- 诊断显示与 LspAttach 键位用 nvim 0.12 原生 API，不依赖任何 LSP 插件包。
local lang = require('config.lang')

-- 启用 lang.lua 清单里的语言服务器（0.12 原生：lsp/<name>.lua 只是注册 config，
-- 必须 vim.lsp.enable 才按 filetypes 懒启动；Java 由 nvim-jdtls 接管，不在清单）
for _, name in ipairs(lang.servers) do
  vim.lsp.enable(name)
end

-- ── 通用 LSP 行为：诊断显示 + LspAttach 键位 ──
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
})

-- 进 LSP 时绑一组通用键位
-- gd 手写补绑：实测 nvim 0.12.3 内置默认只有 K/[d/]d/gO/tagfunc，gd/gD 不在其中（2026-08-26）
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
    end
    -- g 前缀：跳转式（LazyVim 风格，覆盖官方 gr 前缀的单键版）
    map('n', 'gd', vim.lsp.buf.definition, '跳转定义')
    map('n', 'gr', vim.lsp.buf.references, '引用')
    map('n', 'gI', vim.lsp.buf.implementation, '实现')
    map('n', 'gy', vim.lsp.buf.type_definition, '类型定义')
    -- <leader>c 前缀：命令式（与 g 跳转互补）
    map('n', '<leader>ca', vim.lsp.buf.code_action, '代码操作')
    map('n', '<leader>cr', vim.lsp.buf.rename, '重命名')
    map('n', '<leader>cd', vim.diagnostic.open_float, '行诊断')
  end,
})

return {
  -- mason：管理 LSP/格式化 二进制（装 jdtls 就靠它）
  { 'williamboman/mason.nvim', cmd = 'Mason', build = ':MasonUpdate', opts = {} },

  -- mason-tool-installer：自动安装 lang.lua 里列的工具（jdtls + google-java-format）
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    event = 'VeryLazy',
    opts = {
      ensure_installed = lang.mason_tools,
      auto_update = true,
    },
  },

  -- LSP 进度/UI 美化（右下角显示加载进度条）
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },

  -- Java：nvim-jdtls（官方推荐的 Java LSP 前端，start_or_attach 方案）
  -- 仅以 ft=java 懒加载，全部配置在 ftplugin/java.lua
  { 'mfussenegger/nvim-jdtls', ft = 'java' },
}
