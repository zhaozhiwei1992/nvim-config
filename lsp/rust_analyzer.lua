-- rust_analyzer —— Rust 语言服务器（LSP）
-- 提供：补全、跳转定义/引用、诊断、重命名、悬停文档。
-- 安装：rustup component add rust-analyzer（本机已装，位于 ~/.cargo/bin），
--       不放进 mason_tools，避免与 rustup 版本不一致。
-- 字段含义：
--   settings['rust-analyzer'].cargo.allFeatures       分析覆盖全部 Cargo features
--   settings['rust-analyzer'].cargo.loadOutDirsFromCheck  从 cargo check 结果读 build.rs 输出
--   settings['rust-analyzer'].cargo.buildScripts      分析 build.rs（构建脚本/宏依赖）
--   settings['rust-analyzer'].checkOnSave.command     保存后检查用 clippy（比 rustc 更严格）
--   settings['rust-analyzer'].procMacro.enable        展开过程宏（derive 宏等）
return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', '.git' },
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = true, loadOutDirsFromCheck = true, buildScripts = true },
      checkOnSave = { command = 'clippy', extraArgs = { '--no-deps' } },
      procMacro = { enable = true },
    },
  },
}