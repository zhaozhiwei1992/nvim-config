-- rust_analyzer —— Rust
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
