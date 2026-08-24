-- config/lang.lua —— 各语言 LSP/格式化/DAP 清单集中管理
-- 放在 config/ 下而非 plugins/，避免被 lazy.nvim 误判为插件 spec
-- 被 lua/plugins/lsp.lua 的 vim.lsp.enable 和 mason-tool-installer 引用
local M = {}

-- 启用的 LSP 名称（对应 vim.lsp.enable，配置见 ~/.config/nvim/lsp/<name>.lua）
M.servers = {
  'gopls',
  'rust_analyzer',
  'basedpyright',
  'ruff',
  'vtsls', -- TS/JS
  -- 'jdtls' 不在此列：Java 由 nvim-jdtls 插件 start_or_attach 接管（ftplugin/java.lua），
  -- 若在这里 vim.lsp.enable('jdtls') 会与插件双 client（两个 JVM 进程）
  'lua_ls', -- nvim 配置自身
  'clangd', -- C/C++（可选）
}

-- mason 自动安装的工具（LSP + 格式化 + DAP）
-- 注意：rust-analyzer 用 rustup 系统组件更稳，但此处仍列为兜底（已装可跳过）
M.mason_tools = {
  'gopls',
  'delve',
  'goimports',
  'gofumpt',
  'basedpyright',
  'ruff',
  'debugpy',
  'vtsls',
  'eslint-lsp',
  'prettier',
  'stylua',
  'shfmt',
  'google-java-format',
  'taplo',
  'lua-language-server', -- lua_ls（nvim 配置自身）
  'clangd', -- C/C++
  'jdtls', -- Java：新版 mason 源不走 eclipse，2026-08-24 实测可装（见文档「jdtls 特殊说明」）
  -- 'codelldb', -- 已装
  -- 'rust-analyzer', -- 推荐用 rustup 组件：rustup component add rust-analyzer
}

return M
