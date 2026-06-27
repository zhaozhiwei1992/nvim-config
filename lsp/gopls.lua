-- gopls —— Go
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
