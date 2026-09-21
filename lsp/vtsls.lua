-- vtsls —— TypeScript / JavaScript 的 LSP（typescript-language-server 的社区维护分支，
--   对新 TS 版本跟进更快；vue-demo 等前端项目开箱即用）
-- 负责：补全 / 跳转 / 诊断 / 重命名 / 组织 import
return {
  cmd = { 'vtsls', '--stdio' }, -- mason 装的可执行文件（mason bin 自动注入 PATH）
  filetypes = {                -- 触发本 server 的文件类型（懒启动）
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = { 'tsconfig.json', 'package.json', 'jsconfig.json', '.git' }, -- 项目根判定
  settings = {
    complete_function_calls = true,                      -- 补全函数调用时自动带括号/参数提示
    vtsls = { autoUseWorkspaceTsdk = true },             -- 优先用项目本地 typescript 版本
    typescript = {
      updateImportsOnFileMove = { enabled = 'always' },  -- 移动文件时自动更新 import
      suggest = { completeFunctionCalls = true },        -- 与顶层选项同义（兼容字段）
    },
  },
}