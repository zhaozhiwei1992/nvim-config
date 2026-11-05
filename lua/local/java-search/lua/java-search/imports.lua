-- imports.lua —— import 区的两半：① 补缺失 import（自己实现）② 排序/删未用（gjf）
-- 为什么分两半：google-java-format 的 --fix-imports-only 只排序 + 删未用，
--   **不会**补缺失的 import（服务端不知道简单类名对应哪个 FQN），补必须靠索引反查。
-- 对外只暴露一个 <leader>ci（fix_all），内部两个函数可独立调用，便于定位问题。
local util = require('java-search.util')
local index = require('java-search.index')
local picker = require('java-search.picker')
local jdk = require('java-search.jdk')
local deps = require('java-search.deps')

local M = {}

-- mason 装的 gjf（init.lua 已把 mason/bin 注入 PATH）
local GJF = 'google-java-format'

--- 扫描 buffer 的 import 区
---@param bufnr integer
---@return integer|nil first 首个 import 行号（1-based）
---@return integer|nil last  末个 import 行号
---@return table<string, integer> fqns fqn → 行号
function M.get_imports(bufnr)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(200, total), false)
  local first, last, fqns = nil, nil, {}
  for i, line in ipairs(lines) do
    local fqn = line:match('^%s*import%s+static%s+([%w_.]+)%s*;') or line:match('^%s*import%s+([%w_.]+)%s*;')
    if fqn then
      first = first or i
      last = i
      fqns[fqn] = i
    end
  end
  return first, last, fqns
end

--- 插入一行 import（按字母序就位；无 import 块时插在 package 之后）
---@param bufnr integer
---@param fqn string
---@return { at: integer, count: integer }|nil info 插入起点行号与插入行数（未插入返回 nil）
local function insert_import(bufnr, fqn)
  local first, last, fqns = M.get_imports(bufnr)
  if fqns[fqn] then return nil end
  local new_line = 'import ' .. fqn .. ';'

  if first then
    local target = last + 1
    for i = first, last do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ''
      local name = line:match('^%s*import%s+static%s+([%w_.]+)%s*;') or line:match('^%s*import%s+([%w_.]+)%s*;')
      if name and name > fqn then
        target = i
        break
      end
    end
    vim.api.nvim_buf_set_lines(bufnr, target - 1, target - 1, false, { new_line })
    return { at = target, count = 1 }
  end

  -- 无 import 块：找 package 行，其后空一行插入（插 2 行：空行 + import）
  local total = vim.api.nvim_buf_line_count(bufnr)
  local head = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(40, total), false)
  for i, line in ipairs(head) do
    if line:match('^%s*package%s+') then
      vim.api.nvim_buf_set_lines(bufnr, i, i, false, { '', new_line })
      return { at = i + 1, count = 2 }
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { new_line, '' })
  return { at = 1, count = 2 }
end

--- 插 import 后光标会自动下移（文本被推下去），这里把它拉回原标识符
---@param bufnr integer
---@param fqn string
---@return boolean
local function insert_import_keeping_cursor(bufnr, fqn)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local info = insert_import(bufnr, fqn)
  if not info then return false end
  local row = cursor[1]
  if info.at <= row then row = row + info.count end
  local last = vim.api.nvim_buf_line_count(bufnr)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.min(row, last), cursor[2] })
  return true
end

---@param t table 索引条目
---@return string
local function render(t)
  if t.kind == 'dep' then return ('%s  [dep]'):format(t.fqn) end
  if not t.path or t.path == '' then return ('%s  [jdk]'):format(t.fqn) end
  return ('%s  [%s]'):format(t.fqn, t.kind)
end

--- 光标下标识符 → 补 import
---@param opts? { quiet?: boolean, then_organize?: boolean }
---@return 'inserted'|'pending'|'none'
function M.import_here(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand('<cword>')
  local function done(state, msg)
    if msg and not opts.quiet then util.notify(msg, vim.log.levels.WARN) end
    return state
  end
  if word == '' then return done('none', '光标下没有标识符') end

  local hits = index.types_by_name(word, bufnr)
  if #hits == 0 then
    -- 依赖（pom 引用的 jar）：L1 类名→FQN 表，不需要源码就能补 import
    for _, c in ipairs(deps.lookup(word, bufnr)) do
      hits[#hits + 1] = { name = word, fqn = c.fqn, kind = 'dep', jar = c.jar }
    end
  end
  if #hits == 0 then
    -- 项目内与依赖都没有 → 查 JDK 静态表（List/Map/Optional 这类高频类型）
    local fqn = jdk.lookup(word)
    if fqn then hits = { { name = word, fqn = fqn, kind = 'jdk' } } end
  end
  if #hits == 0 then
    return done('none', ('索引里没有类型 "%s"（先 <leader>gB 建索引？）'):format(word))
  end

  -- 过滤：同包无需 import；已 import 的不重复插；默认包类型无法 import
  local pkg = index.package_of_buffer(bufnr)
  local _, _, fqns = M.get_imports(bufnr)
  local candidates, seen = {}, {}
  for _, h in ipairs(hits) do
    local unit = h.fqn:match('^(.*)%.[^.]+$')
    if unit and not seen[h.fqn] and not fqns[h.fqn] and unit ~= pkg then
      seen[h.fqn] = true
      candidates[#candidates + 1] = h
    end
  end

  if #candidates == 0 then
    return done('none', ('"%s" 不需要补 import（同包或已 import）'):format(word))
  end

  if #candidates == 1 then
    insert_import_keeping_cursor(bufnr, candidates[1].fqn)
    return 'inserted'
  end

  table.sort(candidates, function(a, b) return a.fqn < b.fqn end)
  picker.select(candidates, render, function(chosen)
    insert_import_keeping_cursor(bufnr, chosen.fqn)
    if opts.then_organize then M.organize({ join_undo = true }) end
  end, { prompt = ('"%s" 多个候选> '):format(word) })
  return 'pending'
end

--- 用 gjf --fix-imports-only 整理 import（排序 + 删未用；不改其余代码）
---@param opts? { join_undo?: boolean } join_undo：与上一次修改（插 import）合并成一个 undo 步
---@return boolean ok
function M.organize(opts)
  opts = opts or {}
  if vim.fn.executable(GJF) == 0 then
    util.notify('找不到 google-java-format（mason 装过了吗？）', vim.log.levels.WARN)
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n') .. '\n'
  local res = util.run({ GJF, '--fix-imports-only', '-' }, { stdin = content })
  if res.code ~= 0 or res.stdout == '' then
    -- 语法不完整时 gjf 会失败：保留已插入的 import，只提示，不覆盖 buffer
    util.notify('gjf 整理失败（文件语法不完整？）：' .. vim.trim(res.stderr), vim.log.levels.WARN)
    return false
  end

  local new_lines = vim.split((res.stdout:gsub('\n$', '')), '\n', { plain = true })
  if vim.deep_equal(new_lines, lines) then return true end

  -- gjf --fix-imports-only 只动 import 区，所以光标在其下方时按行数差平移（winrestview 在变行后不可靠）
  local _, last_import = M.get_imports(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local delta = #new_lines - #lines
  local row = cursor[1]
  if last_import and row > last_import then row = row + delta end
  row = math.max(1, math.min(row, #new_lines))

  if opts.join_undo then pcall(vim.cmd, 'undojoin') end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  pcall(vim.api.nvim_win_set_cursor, 0, { row, cursor[2] })
  return true
end

--- <leader>ci 入口：先补后整理（补 import 走索引，整理走 gjf）
function M.fix_all()
  local state = M.import_here({ quiet = true, then_organize = true })
  if state == 'pending' then return end -- 候选选择是异步的，选完自己调 organize
  M.organize({ join_undo = state == 'inserted' })
end

return M
