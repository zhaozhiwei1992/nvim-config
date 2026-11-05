-- deps.lua —— 依赖（pom 引用的 jar）支持：方案 A「按需懒解压」
-- 关键设计：
--   1) 版本必须精确 → 不自己解析 pom，直接问 maven：
--      mvn dependency:build-classpath -Dmdep.outputFile=... -Dmdep.includeScope=runtime
--      输出是解析后的**绝对路径 jar 列表**（含传递依赖与版本仲裁），天然正确。
--   2) 不碰整个 ~/.m2（2.6G）→ 只处理当前项目 classpath 里的 jar。
--   3) 三级数据：
--      L1  类名 → {fqn, jar}     ：unzip -Z1 读 .class 路径（85 jar ≈1.1s），零源码磁盘，够补 import
--      L1.5 class → 所属 jar     ：顺带得到，懒解压时才知道该解哪个 jar
--      L2  依赖源码               ：gd 真正落到某类时，才解压它那一个 -sources.jar（几 MB）并索引
--   4) 全部异步：mvn 与 unzip 都在后台跑，不阻塞 UI；未就绪时调用方降级并提示。
local util = require('java-search.util')
local index = require('java-search.index')

local M = {}

---@type { root: string|nil, key: string|nil, status: 'idle'|'running'|'ready'|'failed', dir: string|nil, pom: string|nil, error: string|nil }
local state = { root = nil, key = nil, status = 'idle', dir = nil, pom = nil }

-- 提取 jar 内顶层类路径 → "jar<TAB>a.b.C"（跳过内部类/META-INF/module-info）
local EXTRACT_SCRIPT = [[
while IFS= read -r j; do
  [ -f "$j" ] || continue
  unzip -Z1 "$j" 2>/dev/null \
    | grep -E '\.class$' \
    | grep -vE '\$|^META-INF/|^module-info\.class$|^package-info\.class$' \
    | awk -v j="$j" '{ sub(/\.class$/, ""); gsub(/\//, "."); print j "\t" $0 }'
done < "$1"
]]

---@param path string
---@return table|nil
local function read_json(path)
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
  if not ok or type(data) ~= 'table' then return nil end
  return data
end

---@param path string
---@param data table
---@return boolean
local function write_json(path, data)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then return false end
  local fd = io.open(path, 'w')
  if not fd then return false end
  fd:write(encoded)
  fd:close()
  return true
end

---@param key string 缓存键（用 pom 路径：同一项目不同模块的 classpath 不同，必须分开存）
---@return string
local function dir_of(key)
  return vim.fs.joinpath(util.cache_dir(), 'deps', util.hash(key))
end

--- 向上收集候选 pom（最多 4 层）：多模块 reactor 里单模块 pom 常因兄弟模块 SNAPSHOT 解析不了，
--- 需要逐层上溯到父 pom（父级 classpath 更全，不会漏，对补 import / 跳转反而更好）
---@param bufnr integer
---@return string[] poms
local function pom_candidates(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local cur = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  local out, seen, depth = {}, {}, 0
  -- 不限层数（源码可能在 target/generated-sources/ 下，向上十几层才到模块根），只限“收集到几个 pom”
  while cur and #out < 4 and depth < 25 do
    local p = vim.fs.joinpath(cur, 'pom.xml')
    if vim.fn.filereadable(p) == 1 and not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
    local parent = vim.fs.dirname(cur)
    if parent == cur then break end
    cur, depth = parent, depth + 1
  end
  return out
end

--- 读取 classpath 文件（':“ 分隔的绝对路径）
---@param path string
---@return string[] jars
local function parse_classpath(path)
  if vim.fn.filereadable(path) ~= 1 then return {} end
  local content = table.concat(vim.fn.readfile(path), '')
  local jars = {}
  for entry in content:gmatch('[^:\r\n]+') do
    if entry:match('%.jar$') and vim.fn.filereadable(entry) == 1 then
      jars[#jars + 1] = entry
    end
  end
  return jars
end

--- 把 jar 列表写成临时文件（供 EXTRACT_SCRIPT 读取）
---@param jars string[]
---@return string path
local function write_jar_list(jars)
  local path = vim.fs.joinpath(state.dir, 'jars.txt')
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(jars, path)
  return path
end

--- 第二段：提取 FQN 表（后台）
---@param jars string[]
local function build_classes(jars)
  local jar_list = write_jar_list(jars)
  local classes_file = vim.fs.joinpath(state.dir, 'classes.json')
  vim.system({ 'bash', '-c', EXTRACT_SCRIPT, 'bash', jar_list }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        state.status = 'failed'
        state.error = '读取 jar 内容失败：' .. vim.trim(obj.stderr or '')
        util.notify('依赖索引失败：' .. state.error, vim.log.levels.ERROR)
        return
      end

      local entries = {}
      local count = 0
      for line in (obj.stdout or ''):gmatch('[^\r\n]+') do
        local jar, fqn = line:match('^(.-)\t(.+)$')
        if jar and fqn then
          local name = fqn:match('([^.]+)$')
          if name then
            entries[name] = entries[name] or {}
            table.insert(entries[name], { fqn = fqn, jar = jar })
            count = count + 1
          end
        end
      end

      write_json(classes_file, { generated = os.time(), count = count, entries = entries })
      state.status = 'ready'
      util.notify(('依赖索引就绪：%d 个 jar，%d 个类（补 import 已可用）'):format(#jars, count))
    end)
  end)
end

--- 第一段：跑 mvn 拿 classpath（后台）；失败→离线重试→仍失败→交给 on_fail（上溯父 pom）
---@param pom string
---@param offline boolean
---@param on_fail fun()
local function run_mvn(pom, offline, on_fail)
  local cp_file = vim.fs.joinpath(state.dir, 'classpath.txt')
  local cmd = { 'mvn', '-q', '-f', pom, 'dependency:build-classpath', '-Dmdep.outputFile=' .. cp_file, '-Dmdep.includeScope=runtime' }
  if offline then table.insert(cmd, 2, '-o') end

  vim.system(cmd, { text = true, timeout = 180000 }, function(obj)
    vim.schedule(function()
      local jars = parse_classpath(cp_file)
      if #jars == 0 then
        if not offline then
          run_mvn(pom, true, on_fail)
        else
          on_fail()
        end
        return
      end
      state.pom = pom
      write_json(vim.fs.joinpath(state.dir, 'meta.json'), {
        pom = pom,
        pom_mtime = vim.fn.getftime(pom),
        generated = os.time(),
        jars = jars,
      })
      build_classes(jars)
    end)
  end)
end

--- 按候选 pom 顺序尝试（模块 → 父 → 祖父…）
---@param poms string[]
---@param idx integer
local function try_poms(poms, idx)
  if idx > #poms then
    state.status = 'failed'
    state.error = ('mvn 解析 classpath 失败（已试 %d 层 pom）'):format(#poms)
    util.notify(
      '依赖索引失败：' .. state.error .. '\n项目内搜索与 JDK 补 import 不受影响。',
      vim.log.levels.WARN
    )
    return
  end
  local pom = poms[idx]
  state.pom = pom
  run_mvn(pom, false, function() try_poms(poms, idx + 1) end)
end

--- 缓存是否仍然有效（pom 没改 + 文件都在）
---@param meta table
---@return boolean
local function meta_valid(meta)
  if type(meta.pom) ~= 'string' or type(meta.jars) ~= 'table' then return false end
  if vim.fn.getftime(meta.pom) ~= meta.pom_mtime then return false end
  return true
end

--- 确保依赖索引已加载/构建中
--- 返回 true 表示现在就能用 L1 查询
---@param bufnr? integer
---@return boolean ready
function M.ensure(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  local poms = pom_candidates(bufnr)
  local root = util.root(bufnr)

  -- 用“请求的模块 pom”做键：同一项目不同模块的 classpath 不同，不能因为 root 相同就直接复用
  if state.key == poms[1] and (state.status == 'ready' or state.status == 'running') then
    return state.status == 'ready'
  end
  if #poms == 0 then return false end

  local pom = poms[1]
  state.root, state.key, state.pom, state.dir = root, pom, pom, dir_of(pom)
  local meta = read_json(vim.fs.joinpath(state.dir, 'meta.json'))
  local classes = read_json(vim.fs.joinpath(state.dir, 'classes.json'))
  if meta and classes and meta_valid(meta) and classes.entries then
    state.status = 'ready'
    return true
  end

  state.status = 'running'
  util.notify('正在解析 mvn 依赖 classpath（首次约几秒，完成会提示）…')
  try_poms(poms, 1)
  return false
end

--- L1：类名 → 候选列表 {{fqn, jar}}
---@param name string
---@param bufnr? integer
---@return table[]
function M.lookup(name, bufnr)
  if not M.ensure(bufnr) then return {} end
  local classes = read_json(vim.fs.joinpath(state.dir, 'classes.json'))
  if not classes or not classes.entries then return {} end
  return classes.entries[name] or {}
end

--- 懒解压某个 jar 的 -sources.jar（已解压则直接返回目录）
---@param jar string
---@return string|nil srcdir
function M.ensure_source(jar)
  local src_jar = jar:gsub('%.jar$', '-sources.jar')
  if vim.fn.filereadable(src_jar) ~= 1 then return nil end
  local dest = vim.fs.joinpath(state.dir, 'src', vim.fn.fnamemodify(jar, ':t:r'))
  local marker = vim.fs.joinpath(dest, '.java-search-unpacked')
  if vim.fn.filereadable(marker) == 1 then return dest end

  vim.fn.mkdir(dest, 'p')
  local res = util.run({ 'unzip', '-q', '-o', src_jar, '-d', dest })
  if res.code ~= 0 then return nil end
  local fd = io.open(marker, 'w')
  if fd then
    fd:write('ok')
    fd:close()
  end
  return dest
end

--- 对已解压的依赖源码目录增量建索引（结果存 srcindex.json）
---@param dir string
---@return table|nil types
local function index_source_dir(dir)
  local idx_file = vim.fs.joinpath(state.dir, 'srcindex.json')
  local data = read_json(idx_file) or { generated = 0, dirs = {}, types = {}, members = {} }
  local done = {}
  for _, d in ipairs(data.dirs or {}) do
    done[d] = true
  end
  if done[dir] then return data end

  local scanned = index.scan_dir(dir)
  if not scanned then return data end
  for _, t in ipairs(scanned.types) do
    data.types[#data.types + 1] = t
  end
  for _, m in ipairs(scanned.members) do
    data.members[#data.members + 1] = m
  end
  data.dirs[#data.dirs + 1] = dir
  data.generated = os.time()
  write_json(idx_file, data)
  return data
end

--- 依赖源码里按名查类型（会自动解压 + 索引该 jar）
---@param name string
---@param jar string
---@return table|nil type 条目（含 path/lnum，可直接跳转）
function M.type_in_jar(name, jar)
  local dir = M.ensure_source(jar)
  if not dir then return nil end
  local data = index_source_dir(dir)
  if not data then return nil end
  for _, t in ipairs(data.types) do
    if t.name == name then return t end
  end
  return nil
end

--- 依赖源码里按名查类型（不触发解压，只查已索引的）
---@param name string
---@return table[]
function M.types_by_name(name)
  if not state.dir then return {} end
  local data = read_json(vim.fs.joinpath(state.dir, 'srcindex.json'))
  if not data or not data.types then return {} end
  local hits = {}
  for _, t in ipairs(data.types) do
    if t.name == name then hits[#hits + 1] = t end
  end
  return hits
end

--- 强制重跑 mvn + 重建 L1（:JavaDepsRefresh）
function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local poms = pom_candidates(bufnr)
  if #poms == 0 then
    util.notify('当前 buffer 不在 maven 项目里（找不到 pom.xml）', vim.log.levels.WARN)
    return
  end
  state.status, state.dir, state.pom = 'idle', dir_of(poms[1]), poms[1]
  state.key = poms[1]
  state.root = util.root(bufnr)
  vim.fn.delete(vim.fs.joinpath(state.dir, 'classes.json'))
  vim.fn.delete(vim.fs.joinpath(state.dir, 'meta.json'))
  M.ensure(bufnr)
end

---@return string
function M.status()
  return ('deps=%s root=%s dir=%s%s'):format(
    state.status,
    tostring(state.root),
    tostring(state.dir),
    state.error and (' error=' .. state.error) or ''
  )
end

return M
