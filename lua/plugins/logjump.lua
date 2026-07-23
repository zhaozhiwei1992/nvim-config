-- logjump.lua —— 本地插件 spec（逻辑在 lua/local/logjump/，命令/键位在其 plugin/ 下）
return {
  {
    dir = vim.fn.stdpath('config') .. '/lua/local/logjump',
    name = 'logjump',
    lazy = false,
  },
}
