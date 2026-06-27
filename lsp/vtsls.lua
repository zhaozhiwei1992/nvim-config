-- vtsls —— TypeScript / JavaScript
return {
  cmd = { 'vtsls', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = { 'tsconfig.json', 'package.json', 'jsconfig.json', '.git' },
  settings = {
    complete_function_calls = true,
    vtsls = { autoUseWorkspaceTsdk = true },
    typescript = {
      updateImportsOnFileMove = { enabled = 'always' },
      suggest = { completeFunctionCalls = true },
    },
  },
}
