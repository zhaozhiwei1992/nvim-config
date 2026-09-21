-- ruff —— Python 的 lint + 格式化 LSP（Ruff 官方 server）
-- 分工：basedpyright 管类型/诊断，ruff 管 lint 规则与代码格式化，两者并存不冲突
return {
  cmd = { 'ruff', 'server' }, -- mason 装的可执行文件（ruff 包）
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' }, -- 项目根判定（同时找 ruff 配置）
}