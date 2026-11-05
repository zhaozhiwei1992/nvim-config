-- init.lua —— java-search 对外 API（导航 / 符号 / import）
-- 键位与命令注册在 plugin/java-search.lua；本文件只导出函数，插件加载时不做事。
local util = require('java-search.util')
local index = require('java-search.index')
local symbols = require('java-search.symbols')
local picker = require('java-search.picker')
local imports = require('java-search.imports')
local deps = require('java-search.deps')

local M = {}

-- 暴露给验证/调试用（:lua print(#require('java-search').index.all_types())）
M.index = index
M.imports = imports
M.deps = deps

---@param item table
---@param lnum integer
---@param col? integer
local function jump_to(item, lnum, col)
  if not item or not item.path then return end
  if vim.fn.filereadable(item.path) == 0 then
    util.notify('文件不存在：' .. item.path, vim.log.levels.WARN)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(item.path))
  lnum = math.max(1, math.min(lnum or 1, vim.api.nvim_buf_line_count(0)))
  col = math.max(0, (col or 1) - 1)
  pcall(vim.api.nvim_win_set_cursor, 0, { lnum, col })
  vim.cmd('normal! zvzz')
end

---@param t table
---@return string
local function render_type(t)
  return ('%s  [%s]  %s:%d'):format(t.fqn, t.kind, vim.fn.fnamemodify(t.path, ':.'), t.lnum)
end

---@param m table
---@return string
local function render_member(m)
  -- 索引里的 sig 是 rg -o 截断到 '(' 的片段，参数表在源文件里：读回整行更准
  local full = util.read_line(m.path, m.lnum)
  local text = vim.trim(full or m.sig)
  if #text > 120 then text = text:sub(1, 117) .. '...' end
  return ('%s  %s:%d'):format(text, vim.fn.fnamemodify(m.path, ':.'), m.lnum)
end

---@param c table {{fqn: string, jar: string}}
---@return string
local function render_dep(c)
  return ('%s  [%s]'):format(c.fqn, vim.fn.fnamemodify(c.jar, ':t:r'))
end

--- 从依赖（pom 的 jar）里跳转：L1 查 FQN → 懒解压该 jar 的 sources → 跳
---@param word string
---@return boolean handled 已处理（无论跳成功与否），调用方不再回落 grep
local function try_deps_jump(word)
  if not deps.ensure() then
    return false -- 后台构建中或不可用，已由 deps 通知
  end
  local cands = deps.lookup(word)
  if #cands == 0 then return false end

  local function go(c)
    local t = deps.type_in_jar(word, c.jar)
    if t then
      jump_to(t, t.lnum)
      return
    end
    util.notify(
      ('依赖类 %s 没有 -sources.jar，无法跳转（补 import 仍可用）'):format(c.fqn),
      vim.log.levels.WARN
    )
  end

  if #cands == 1 then
    go(cands[1])
    return true
  end
  picker.select(cands, render_dep, go, { prompt = ('依赖 %s> '):format(word) })
  return true
end

--- gd：类型优先，其次方法，都没有则回落文本搜索
function M.jump_def()
  local word = vim.fn.expand('<cword>')
  if word == '' then
    util.notify('光标下没有标识符', vim.log.levels.WARN)
    return
  end

  local types = index.types_by_name(word)
  if #types == 1 then return jump_to(types[1], types[1].lnum) end
  if #types > 1 then
    table.sort(types, function(a, b) return a.fqn < b.fqn end)
    picker.select(types, render_type, function(t) jump_to(t, t.lnum) end, { prompt = ('类型 %s> '):format(word) })
    return
  end

  local members = index.members_by_name(word)
  if #members == 1 then return jump_to(members[1], members[1].lnum) end
  if #members > 1 then
    picker.select(members, render_member, function(m) jump_to(m, m.lnum) end, { prompt = ('方法 %s> '):format(word) })
    return
  end

  -- 依赖（pom 引用的 jar）
  if try_deps_jump(word) then return end

  util.notify(('索引未命中 "%s"，回落文本搜索'):format(word))
  picker.grep(word)
end

--- gD / gy：只查类型声明
function M.jump_decl()
  local word = vim.fn.expand('<cword>')
  if word == '' then
    util.notify('光标下没有标识符', vim.log.levels.WARN)
    return
  end
  local types = index.types_by_name(word)
  if #types == 1 then return jump_to(types[1], types[1].lnum) end
  if #types > 1 then
    table.sort(types, function(a, b) return a.fqn < b.fqn end)
    picker.select(types, render_type, function(t) jump_to(t, t.lnum) end, { prompt = ('类型 %s> '):format(word) })
    return
  end
  if try_deps_jump(word) then return end
  util.notify(('索引未命中类型 "%s"，回落文本搜索'):format(word))
  picker.grep(word)
end

--- <leader>fs：项目类型符号
function M.pick_types()
  local types = index.all_types()
  if #types == 0 then
    util.notify('索引为空（先 <leader>gB 建索引）', vim.log.levels.WARN)
    return
  end
  table.sort(types, function(a, b)
    if a.name == b.name then return a.fqn < b.fqn end
    return a.name < b.name
  end)
  picker.select(types, render_type, function(t) jump_to(t, t.lnum) end, { prompt = '项目类型> ' })
end

--- <leader><F12>：当前 buffer 符号（treesitter）
function M.buffer_symbols()
  local items = symbols.collect(0)
  if not items or #items == 0 then
    util.notify('treesitter 解析失败或本文件无符号', vim.log.levels.WARN)
    return
  end
  picker.select(items, function(it)
    return ('%s  [%s]  :%d'):format(it.name, it.kind, it.lnum)
  end, function(it)
    vim.api.nvim_win_set_cursor(0, { it.lnum, math.max(0, (it.col or 1) - 1) })
    vim.cmd('normal! zvzz')
  end, { prompt = '本文件符号> ' })
end

--- gr：全项目引用（文本级 \b 词边界，注释/字符串会误命中）
function M.references()
  local word = vim.fn.expand('<cword>')
  if word == '' then
    util.notify('光标下没有标识符', vim.log.levels.WARN)
    return
  end
  picker.grep('\\b' .. word .. '\\b')
end

--- gi：找接口/抽象类的实现（文本近似；Spring 的 @Bean 注册靠手搜，见笔记 §10）
function M.implementations()
  local word = vim.fn.expand('<cword>')
  if word == '' then
    util.notify('光标下没有标识符', vim.log.levels.WARN)
    return
  end
  picker.grep('implements ' .. word)
end

--- <leader>ci：补 import + gjf 整理
function M.fix_imports()
  imports.fix_all()
end

--- :JavaImportHere —— 只补 import，不整理
function M.import_here()
  imports.import_here()
end

--- :JavaOrganizeImports —— 只整理（排序 + 删未用）
function M.organize_imports()
  imports.organize()
end

--- <leader>gB / :JavaSearchRefresh —— 强制重建索引
function M.refresh()
  index.refresh()
end

--- :JavaDepsRefresh —— 重跑 mvn 解析依赖 classpath，重建依赖索引
function M.refresh_deps()
  deps.refresh()
end

--- :JavaDepsStatus —— 看依赖索引状态（排障用）
function M.deps_status()
  print(require('java-search.deps').status())
end

return M
