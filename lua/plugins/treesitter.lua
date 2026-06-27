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

      -- 2) 高亮 + 折叠 + 缩进：FileType 时启动 treesitter（parser 缺失时 pcall 兜底）
      --    折叠/缩进必须在 treesitter 成功启动的缓冲上设置，否则原 vim.wo/vim.bo
      --    写法只作用于首个窗口，且会在没装 parser 的文件上误触发。
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterStart', {}),
        callback = function(args)
          local ok = pcall(vim.treesitter.start, args.buf)
          if not ok then
            return
          end
          -- 仅在 treesitter 成功启动的缓冲上启用基于语法的折叠/缩进
          vim.bo[args.buf].foldmethod = 'expr'
          vim.wo[0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
