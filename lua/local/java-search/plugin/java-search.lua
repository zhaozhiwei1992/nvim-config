-- java-search 插件入口：命令 + ft=java 的 buffer-local 键位
-- lazy spec 见 lua/plugins/java_search.lua（dir 引入，lazy=false）
-- 键位刻意沿用 jdtls 时代那套（gd/gD/gy/<leader>fs/<leader><F12>/<leader>ci），只换后端。
local M = require('java-search')

local api = vim.api

-- 全局命令（与键位一一对应，方便 : 调用和排查）
api.nvim_create_user_command('JavaSearchRefresh', function() M.refresh() end, { desc = 'Java: 重建搜索索引' })
api.nvim_create_user_command('JavaSearchOnce', function() M.jump_def() end, { desc = 'Java: 跳到光标处符号的定义' })
api.nvim_create_user_command('JavaImportHere', function() M.import_here() end, { desc = 'Java: 为光标处类型补 import' })
api.nvim_create_user_command('JavaOrganizeImports', function() M.organize_imports() end, { desc = 'Java: 整理 import（gjf）' })
api.nvim_create_user_command('JavaBufferSymbols', function() M.buffer_symbols() end, { desc = 'Java: 本文件符号' })
api.nvim_create_user_command('JavaDepsRefresh', function() M.refresh_deps() end, { desc = 'Java: 重跑 mvn 解析依赖并重建依赖索引' })
api.nvim_create_user_command('JavaDepsStatus', function() M.deps_status() end, { desc = 'Java: 依赖索引状态' })

local group = api.nvim_create_augroup('java_search_keys', { clear = true })

api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'java',
  callback = function(args)
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = 'Java: ' .. desc })
    end
    -- 跳转族：与 LSP 时代同名同键
    map('gd', M.jump_def, '跳到定义（索引）')
    map('gD', M.jump_decl, '跳到类型声明')
    map('gy', M.jump_decl, '类型定义')
    -- 搜索族：文本近似，后端从 LSP 换 rg/fzf
    map('gr', M.references, '引用（文本搜索）')
    map('gi', M.implementations, '实现（implements 搜索）')
    -- 符号族
    map('<leader>fs', M.pick_types, '项目类型符号')
    map('<leader><F12>', M.buffer_symbols, '本文件符号')
    -- import 族：补 + 整理合并为一个键（P0）
    map('<leader>ci', M.fix_imports, '补 import + 整理')
    -- 索引维护
    map('<leader>gB', M.refresh, '重建搜索索引')
  end,
})
