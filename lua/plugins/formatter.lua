-- formatter.lua —— 统一格式化（conform.nvim）
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
        go = { 'goimports', 'gofumpt' },
        rust = { 'rustfmt' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'prettierd' },
        json = { 'prettier' },
        yaml = { 'prettier' },
        toml = { 'taplo' },
        lua = { 'stylua' },
        sh = { 'shfmt' },
        java = { 'google-java-format' },
      },
    },
  },
}
