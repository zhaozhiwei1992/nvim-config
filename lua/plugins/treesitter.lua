-- treesitter.lua —— 基于语法的语法高亮/折叠/文本对象
-- 注意：nvim-treesitter main 分支已废弃 nvim-treesitter.configs 模块与
--       ensure_installed / highlight / indent 选项。新版用原生 vim.treesitter API：
--   - 安装 parser:  require('nvim-treesitter').install{ 'lua', 'html', ... }
--   - 高亮:         vim.treesitter.start(buf)（nvim 原生）
--   - 折叠:         vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--   - 缩进:         vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
local parsers = {
  'lua', 'vim', 'vimdoc', 'query',
  'go', 'rust', 'python', 'typescript', 'tsx', 'javascript',
  'java', 'html', 'css', 'json', 'yaml', 'toml',
  'markdown', 'markdown_inline',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':lua require("nvim-treesitter.install").update({ with_sync = true })',
    lazy = false,
    config = function()
      -- 1) 启动时异步安装缺失的 parser（不等，不阻塞 UI）
      vim.defer_fn(function()
        local ts = require('nvim-treesitter')
        local installed = {}
        local ok, list = pcall(ts.get_installed)
        if ok then
          for _, l in ipairs(list) do
            installed[l] = true
          end
        end
        for _, lang in ipairs(parsers) do
          if not installed[lang] then
            ts.install({ lang })
          end
        end
      end, 0)

      -- 2) 高亮：FileType 时启动 treesitter（nvim 原生，parser 缺失时 pcall 兜底）
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterStart', {}),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })

      -- 3) 折叠基于 treesitter
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      vim.wo.foldmethod = 'expr'

      -- 4) 缩进（实验性）
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  },
}
