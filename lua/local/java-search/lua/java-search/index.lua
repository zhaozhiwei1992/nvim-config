-- index.lua —— rg 一次扫描建符号索引（types / members / package），落 JSON cache
-- 设计：https://github.com/zhaozhiwei -> PLAN-java-search.md
--   · 扫描用 -o（只输出匹配片段），解析极简：'class Foo' / 'package a.b.c;' / 'public void bar('
--   · --pcre2 用于 (?<![\w@])，避免 @interface Foo 被记成 interface
--   · 方法行用 Lua 侧过滤控制流关键字（if/for/while/... 也会匹配到 'xxx('）
local util = require('java-search.util')

local M = {}

-- 缓存有效期（秒）；过期或 <leader>gB 时重建
M.TTL = 600

local RG_PATTERNS = {
  [[^\s*package\s+[\w.]+;]],
  [[(?<![\w@])(?:class|interface|enum|record|@interface)\s+\w+]],
  [[^[ \t]{1,12}(?:(?:public|protected|private|static|final|abstract|synchronized|native|default)[ \t]+)+[A-Za-z_][\w<>\[\],.?\s]*?[ \t]+\w+[ \t]*\(]],
}

-- 类型行首关键字（-o 从匹配点开始输出，前缀修饰符已被 pattern 吃掉，剩下只有这些）
local TYPE_KEYWORDS = {
  class = true, interface = true, enum = true, record = true, ['@interface'] = true,
}

-- 方法正则也会命中这些控制流写法（if/for/while/do/else/return 是 Lua 关键字，key 必须加方括号）
local CTRL_KEYWORDS = {
  ['if'] = true, ['for'] = true, ['while'] = true, ['switch'] = true, ['catch'] = true,
  ['return'] = true, ['new'] = true, ['synchronized'] = true, ['do'] = true, ['else'] = true,
  ['try'] = true, ['assert'] = true,
}

---@type { root: string|nil, data: table|nil }
local cache = { root = nil, data = nil }

---@param root string
---@return string
local function cache_path(root)
  return vim.fs.joinpath(util.cache_dir(), util.hash(root) .. '.json')
end

---@param root string
---@return table|nil
local function read_cache(root)
  local path = cache_path(root)
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  if not ok or type(data) ~= 'table' or type(data.types) ~= 'table' then return nil end
  if data.root ~= root then return nil end
  if os.time() - (data.generated or 0) > M.TTL then return nil end
  return data
end

---@param root string
---@param data table
local function write_cache(root, data)
  local dir = util.cache_dir()
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    util.notify('索引序列化失败：' .. tostring(encoded), vim.log.levels.WARN)
    return
  end
  local path = cache_path(root)
  local fd = io.open(path, 'w')
  if not fd then
    util.notify('索引写入失败：' .. path, vim.log.levels.WARN)
    return
  end
  fd:write(encoded)
  fd:close()
end

--- 一行 rg 输出 → 结构化条目
---@param out table 收集容器
---@param pkg_of table<string, string> 绝对路径 → package
---@param seen table 去重表
---@param root string
---@param raw string
local function parse_line(out, pkg_of, seen, root, raw)
  local path, lnum, content = raw:match('^(.-):(%d+):(.*)$')
  if not path then return end
  if path:sub(1, 2) == './' then path = path:sub(3) end
  local abs = path:sub(1, 1) == '/' and path or (root .. '/' .. path)
  local line = tonumber(lnum)
  if not line then return end

  -- package 行：只记映射，不入符号表
  local pkg = content:match('^%s*package%s+([%w_.]+)')
  if pkg then
    pkg_of[abs] = pkg
    return
  end

  local head = content:match('^%s*(@?[%a_]+)')
  if not head then return end

  local key = abs .. ':' .. line .. ':' .. head
  if seen[key] then return end
  seen[key] = true

  if TYPE_KEYWORDS[head] then
    local name = content:match('[%w_]+%s*$')
    if not name then return end
    local p = pkg_of[abs]
    out.types[#out.types + 1] = {
      name = name,
      fqn = p and (p .. '.' .. name) or name,
      kind = (head == '@interface') and 'annotation' or head,
      path = abs,
      lnum = line,
    }
    return
  end

  -- 方法/构造器：'public void bar(' → 取 '(' 前最后一个标识符
  -- 注：-o 只给出到 '(' 为止的片段，参数表在源文件里，渲染时用 util.read_line 补全
  local name = content:match('([%w_]+)%s*%($')
  if not name or CTRL_KEYWORDS[name] then return end
  out.members[#out.members + 1] = {
    name = name,
    sig = vim.trim(content),
    path = abs,
    lnum = line,
  }
end

--- 扫描任意目录，返回索引表（不读写缓存）
--- @param root string
--- @return table|nil
function M.scan_dir(root)
  if not util.has_rg() then
    util.notify('找不到 rg，Java 搜索功能不可用', vim.log.levels.ERROR)
    return nil
  end

  local cmd = { 'rg', '--no-heading', '-n', '--with-filename', '-o', '--pcre2', '--no-messages', '-g', '*.java' }
  for _, p in ipairs(RG_PATTERNS) do
    vim.list_extend(cmd, { '-e', p })
  end
  cmd[#cmd + 1] = '.'

  local res = util.run(cmd, { cwd = root })
  -- rg 无匹配时 exit code = 1，不算错误
  if res.code ~= 0 and res.code ~= 1 then
    util.notify('rg 扫描失败（code=' .. res.code .. '）：' .. vim.trim(res.stderr), vim.log.levels.ERROR)
    return nil
  end

  local out = { root = root, generated = os.time(), types = {}, members = {} }
  local pkg_of, seen = {}, {}
  for raw in res.stdout:gmatch('[^\r\n]+') do
    parse_line(out, pkg_of, seen, root, raw)
  end
  out.files = vim.tbl_count(pkg_of)
  return out
end

--- 取当前 buffer 的索引（懒构建：缓存命中直接返回，否则同步扫描）
---@param opts? { bufnr?: integer, force?: boolean }
---@return table|nil
function M.get(opts)
  opts = opts or {}
  local root = util.root(opts.bufnr)
  if cache.data and cache.root == root and not opts.force then
    if os.time() - (cache.data.generated or 0) <= M.TTL then return cache.data end
  end

  if not opts.force then
    local cached = read_cache(root)
    if cached then
      cache.root, cache.data = root, cached
      return cached
    end
  end

  local started = vim.uv.hrtime()
  local data = M.scan_dir(root)
  if not data then return nil end
  local ms = math.floor((vim.uv.hrtime() - started) / 1e6)
  cache.root, cache.data = root, data
  write_cache(root, data)
  if not opts.silent then
    util.notify(('索引完成：%d 个类型 / %d 个方法，%.0f ms'):format(#data.types, #data.members, ms))
  end
  return data
end

--- 强制重建（<leader>gB / :JavaSearchRefresh）
---@return table|nil
function M.refresh()
  cache.root, cache.data = nil, nil
  local data = M.get({ force = true })
  if data then
    vim.cmd('redraw')
  end
  return data
end

--- 按名查类型（精确匹配 name）
---@param name string
---@param bufnr? integer
---@return table[]
function M.types_by_name(name, bufnr)
  local data = M.get({ bufnr = bufnr, silent = true })
  if not data then return {} end
  local hits = {}
  for _, t in ipairs(data.types) do
    if t.name == name then hits[#hits + 1] = t end
  end
  return hits
end

--- 按名查方法
---@param name string
---@param bufnr? integer
---@return table[]
function M.members_by_name(name, bufnr)
  local data = M.get({ bufnr = bufnr, silent = true })
  if not data then return {} end
  local hits = {}
  for _, m in ipairs(data.members) do
    if m.name == name then hits[#hits + 1] = m end
  end
  return hits
end

--- 全部类型（<leader>fs）
---@param bufnr? integer
---@return table[]
function M.all_types(bufnr)
  local data = M.get({ bufnr = bufnr, silent = true })
  return data and data.types or {}
end

--- 当前文件所在 package（读 buffer 行，不依赖索引）
---@param bufnr? integer
---@return string|nil
function M.package_of_buffer(bufnr)
  bufnr = bufnr or 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 40, false)) do
    local pkg = line:match('^%s*package%s+([%w_.]+)%s*;')
    if pkg then return pkg end
  end
  return nil
end

return M
