-- formatter.lua —— 统一格式化（conform.nvim，2026-09-21：Java / Go / Rust / Python / TS·JS / Lua / TOML / shell）
-- 用法：保存时自动按文件类型调对应工具；也可 <leader>cf 手动触发。
--       lsp_fallback=true = 未配 formatter 的文件类型退回用 LSP 自带格式化。
-- 扩展：在 formatters_by_ft 加一行映射 + 工具二进制加进 config/lang.lua 的 M.mason_tools。
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
        json = { 'prettier' },                                           -- 配置文件对齐 prettier（mason 装）
        yaml = { 'prettier' },
        toml = { 'taplo' },                                              -- TOML：mason 装 taplo
        lua  = { 'stylua' },                                             -- Lua：mason 装 stylua
        sh   = { 'shfmt' },                                              -- shell：mason 装 shfmt
      },
    },
  },
}
