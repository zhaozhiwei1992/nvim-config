-- cmp.lua —— 补全（blink.cmp，2026 性能首选）
return {
  {
    'saghen/blink.cmp',
    version = '*', -- 用预编译二进制，快
    event = 'InsertEnter',
    dependencies = { 'rafamadriz/friendly-snippets' },
    opts = {
      keymap = {
                -- preset = 'default'
                -- 直接声明使用 super-tab 预设
                --https://yuanbao.tencent.com/chat/naQivTmsDa/0PrTyWp7oum
                preset = 'super-tab'
            },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
      completion = { documentation = { auto_show = true },
trigger = {
      show_in_snippet = false  -- 避免在代码片段占位符里打字时疯狂弹菜单
    }
            },
      signature = { enabled = true },
    },
  },
}
