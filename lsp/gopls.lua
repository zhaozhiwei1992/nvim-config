-- gopls —— Go 语言服务器（LSP）
-- 提供：补全、跳转定义/引用、诊断、重命名、悬停文档。
-- 安装：mason 自动装（见 config/lang.lua 的 M.mason_tools）。
-- 字段含义：
--   cmd            启动命令（gopls 在 PATH，mason bin 前缀已注入）
--   filetypes      触发启动的文件类型（打开任意 go 文件即 attach）
--   root_markers   项目根判定：含 go.mod 或 .git 的目录为根（LSP workspace 范围）
--   settings.gopls.gofumpt        格式化用 gofumpt（比 gofmt 更严格）
--   settings.gopls.staticcheck    开静态分析（未用变量、错误处理遗漏等）
--   settings.gopls.hints          行内类型提示（变量类型、字面量字段名）
return {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.mod', '.git' },
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
      },
    },
  },
}