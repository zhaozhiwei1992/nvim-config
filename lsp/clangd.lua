-- clangd —— C / C++ 的 LSP（clang 官方；语义级补全/跳转需项目有 compile_commands.json）
-- 负责：补全 / 跳转 / 诊断 / 重构；无 compile_commands.json 时智能有限（可选装）
return {
  cmd = { 'clangd' },                                   -- mason 装的可执行文件
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' }, -- 触发的文件类型
  root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' }, -- 项目根判定
}