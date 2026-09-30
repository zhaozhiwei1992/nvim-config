-- formatter.lua —— 统一格式化（conform.nvim，2026-09-30：Java / Go / Rust / Python / TS·JS / Vue / Lua / TOML / shell / json / yaml / nginx）
-- 用法：保存时自动按文件类型调对应工具；也可 <leader>cf 手动触发。
--       lsp_fallback=true = 未配 formatter 的文件类型退回用 LSP 自带格式化。
-- 扩展：在 formatters_by_ft 加一行映射 + 工具二进制加进 config/lang.lua 的 M.mason_tools。
-- ⚠️ 二进制不在 PATH 时（如 nginxfmt 装在独立 venv），必须在这里的 formatters 表覆写 command 为绝对路径，
--    否则 conform 按裸命令名找不到工具（症状：:ConformInfo 报 unavailable）。
return {
  {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    cmd = { 'ConformInfo' },
    keys = {
      { '<leader>cf', function()
        require('conform').format({ async = true })
      end, desc = '格式化' },
    },
    opts = {
      format_on_save = { timeout_ms = 500, lsp_fallback = true },
      formatters_by_ft = {
        java = { 'google-java-format' },                                 -- Java：mason 装
        go   = { 'goimports', 'gofumpt' },                               -- Go：先理 import 再格式化（mason 装）
        rust = { 'rustfmt' },                                            -- Rust：随 rustc 自带
        python = { 'ruff_organize_imports', 'ruff_format' },             -- Python：ruff（mason 装）
        typescript       = { 'prettierd', 'prettier', stop_after_first = true }, -- TS/JS：prettier（mason 装；prettierd 未装会自动回落）
        typescriptreact  = { 'prettierd', 'prettier', stop_after_first = true },
        javascript       = { 'prettierd', 'prettier', stop_after_first = true },
        vue = { 'prettier' },                                            -- Vue SFC：prettier（volar 不提供 format provider，prettier 是标准选择）
        json = { 'prettier' },                                           -- 配置文件对齐 prettier（mason 装）
        yaml = { 'prettier' },
        nginx = { 'nginxfmt' },                                          -- nginx conf：nginxfmt（独立 venv，command 覆写见下）
        toml = { 'taplo' },                                              -- TOML：mason 装 taplo
        lua  = { 'stylua' },                                             -- Lua：mason 装 stylua
        sh   = { 'shfmt' },                                              -- shell：mason 装 shfmt
      },
    -- 工具可执行文件不在 PATH 时在此覆写 command（绝对路径）
    formatters = {
      -- nginxfmt 用 pip 装在隔离 venv（~/.local/venvs/nginxfmt），不在 PATH；
      -- 重装/迁移方式：python3 -m venv ~/.local/venvs/nginxfmt && \
      --   ~/.local/venvs/nginxfmt/bin/pip install 'git+https://github.com/slomkowski/nginx-config-formatter.git'
      -- （该工具只发布在 GitHub 源码，PyPI 无包；无第三方依赖，纯标准库）
      nginxfmt = { command = vim.fn.expand('~/.local/venvs/nginxfmt/bin/nginxfmt') },
    },
    },
  },
}
