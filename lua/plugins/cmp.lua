-- cmp.lua —— 补全（blink.cmp，2026 性能首选）
return {
  {
    'saghen/blink.cmp',
    version = '*', -- 用预编译二进制，快
    event = 'InsertEnter',
    dependencies = { 'rafamadriz/friendly-snippets' },
    opts = {
      keymap = { preset = 'default' },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
}
