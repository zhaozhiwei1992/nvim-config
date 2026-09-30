-- treesitter.lua —— 基于语法的语法高亮/折叠/文本对象（2026-09-21：Java / Go / Rust / Python / TS·JS / C·C++ / Lua）
-- 注意：nvim-treesitter main 分支已废弃 nvim-treesitter.configs 模块与
--       ensure_installed / highlight / indent 选项。新版用原生 vim.treesitter API：
--   - 安装 parser:  require('nvim-treesitter').install{ 'lua', 'html', ... }
--   - 高亮:         vim.treesitter.start(buf)（nvim 原生）
--   - 折叠:         vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--   - 缩进:         vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
-- parser 清单：java/go/rust 是代码语言；lua/vim/vimdoc/query 是 nvim 自身；
-- 配置与插件；markdown/json/yaml/toml 是笔记与配置文件；vue/nginx 是前端/服务器配置。
-- 没装 parser 的语言只是没有语法高亮/折叠，不影响打开文件；扩展语言在此列表加名字即可（启动时自动装）。
local parsers = {
  -- 代码语言语法高亮（核心）
  'java', 'go', 'rust', 'python', 'c', 'cpp', 'typescript', 'javascript', 'tsx',
  -- nvim 自身配置/插件
  'lua', 'vim', 'vimdoc', 'query',
  -- 笔记
  'markdown', 'markdown_inline',
  -- 配置文件与前端文件
  'json', 'yaml', 'toml', 'html', 'css', 'vue', 'nginx',
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
          -- 注意：foldmethod / foldexpr 是 window-local，必须用 vim.wo；
          --       indentexpr 是 buffer-local，用 vim.bo。
          vim.wo[0].foldmethod = 'expr'
          vim.wo[0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
