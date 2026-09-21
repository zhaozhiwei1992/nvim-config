-- basedpyright —— Python 的 LSP（Pyright 的社区加固分支：更严格的下游风格检查）
-- 负责：补全 / 跳转 / 类型检查 / 诊断；lint 与格式化交给 ruff，两者互补
return {
  cmd = { 'basedpyright-langserver', '--stdio' }, -- mason 装的可执行文件
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', '.git' }, -- 项目根判定
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,        -- 自动把 site-packages 加入搜索路径
        useLibraryCodeForTypes = true, -- 用库内代码推断类型（否则类型信息缺失）
        diagnosticMode = 'openFilesOnly', -- 只诊断打开的文件（避免全项目扫描吃 CPU）
      },
    },
  },
}