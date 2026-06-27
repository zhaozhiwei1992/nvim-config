-- jdtls —— Java（基础配置；如启动异常见文档「jdtls 特殊说明」）
-- jdtls 需 workspace 目录，mason 安装后 cmd 由 mason 提供
return {
  cmd = { 'jdtls' },
  filetypes = { 'java' },
  root_markers = { 'pom.xml', 'build.gradle', 'settings.gradle', '.git' },
  init_options = {
    workspace = vim.fn.stdpath('cache') .. '/jdtls-workspace',
  },
}
