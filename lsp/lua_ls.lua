-- lua_ls —— Lua 的 LSP（lua-language-server；编辑 nvim 配置 / 写插件时提供补全与诊断）
return {
  cmd = { 'lua-language-server' }, -- mason 装的可执行文件
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.jsonc', '.git' }, -- 项目根判定（lua_ls 配置）
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' }, -- nvim 内嵌 Lua 是 LuaJIT 5.1，匹配官方建议
      workspace = {
        checkThirdParty = false,        -- 不做第三方库检查（避免误报）
        library = { vim.env.VIMRUNTIME }, -- 把 nvim 运行时目录加进库路径（认得 vim.* API）
      },
      diagnostics = { globals = { 'vim' } }, -- 声明 vim 为全局（否则报 undefined global）
    },
  },
}