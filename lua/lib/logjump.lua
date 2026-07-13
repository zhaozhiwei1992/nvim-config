-- logjump.lua —— 日志堆栈跳转模块（从 Java 等日志中提取堆栈，定位源文件 + 行号）
-- 位置：lua/lib/logjump.lua（自定义功能模块集中存放）
-- 被 lua/plugins/logjump.lua 引用，命令/键位在 spec 文件中注册

--------------------------------------------------------------------------------
-- 配置区（Configurable Section）
--------------------------------------------------------------------------------

-- 默认的备用搜索目录（当 locate 和当前项目都找不到时使用）
-- 修改为你存放所有 Java / 业务项目的目录
local DEFAULT_SEARCH_DIRS = {
  vim.fn.expand('~/workspace'),
  vim.fn.expand('~/code'),
  '/opt/src',
}

-- locate 是否可用（依赖系统 updatedb 维护的数据库）
local USE_LOCATE = vim.fn.executable('locate') == 1

-- locate 最多返回的结果数
local LOCATE_LIMIT = 10

-- find 搜索最大深度（防止扫描 node_modules 等巨型目录时卡死）
local FIND_MAXDEPTH = 15

--------------------------------------------------------------------------------
-- 私有函数（Private Functions）
--------------------------------------------------------------------------------

--- 检查文件是否可读
---@param path string 文件路径
---@return boolean
local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

--- 获取当前项目根目录（优先 git root，回退 cwd）
---@return string
local function get_project_root()
  local result = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error == 0 and result[1] and result[1] ~= '' then
    return result[1]
  end
  return vim.fn.getcwd()
end

--- 使用 locate 命令搜索文件
---@param filename string 文件名（如 LoginFilter.java）
---@param pkg_path string|nil 包路径（如 com/xxx/），用于优先过滤
---@return string|nil 找到的文件全路径
local function search_via_locate(filename, pkg_path)
  if not USE_LOCATE then
    return nil
  end

  local cmd = { 'locate', '-l', tostring(LOCATE_LIMIT), filename }
  local results = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  -- 如果有包路径，优先匹配包路径的结果
  if pkg_path and pkg_path ~= '' then
    for _, path in ipairs(results) do
      if vim.fn.fnamemodify(path, ':t') == filename
          and path:match('/' .. pkg_path .. '/' .. filename .. '$')
          and file_exists(path)
      then
        return path
      end
    end
  end

  -- 回退到第一个 basename 匹配且文件存在的结果
  for _, path in ipairs(results) do
    if vim.fn.fnamemodify(path, ':t') == filename and file_exists(path) then
      return path
    end
  end

  return nil
end

--- 在指定目录下用 find 搜索文件
---@param dir string 搜索目录
---@param filename string 文件名
---@param pkg_path string|nil 包路径（如 com/xxx/）
---@return string|nil
local function search_in_dir(dir, filename, pkg_path)
  if not dir or dir == '' or vim.fn.isdirectory(dir) ~= 1 then
    return nil
  end

  -- 优先按包路径搜索：*/com/xxx/Filename.java
  if pkg_path and pkg_path ~= '' then
    local path_pattern = '*/' .. pkg_path .. '/' .. filename
    local results = vim.fn.systemlist({
      'find', dir,
      '-type', 'f',
      '-path', path_pattern,
      '-maxdepth', tostring(FIND_MAXDEPTH),
      '-print', '-quit',
    })
    if results[1] and file_exists(results[1]) then
      return results[1]
    end
  end

  -- 回退：仅按文件名搜索
  local results = vim.fn.systemlist({
    'find', dir,
    '-type', 'f',
    '-name', filename,
    '-maxdepth', tostring(FIND_MAXDEPTH),
    '-print', '-quit',
  })
  if results[1] and file_exists(results[1]) then
    return results[1]
  end

  return nil
end

--- 搜索文件缓存（key = "filename|pkg_path"，value = path 或 false）
local search_cache = {}

--- 三级搜索：用户目录 → locate → 当前项目 → 默认目录
---@param filename string 文件名
---@param pkg_path string|nil 包路径
---@param user_dir string|nil 用户指定的搜索目录（最高优先级）
---@return string|nil 找到的文件全路径
local function find_source_file(filename, pkg_path, user_dir)
  local cache_key = filename .. '|' .. (pkg_path or '')
  if search_cache[cache_key] ~= nil then
    local cached = search_cache[cache_key]
    return cached ~= false and cached or nil
  end

  local found = nil

  -- 0. 如果 filename 本身就是可读的绝对路径，直接用
  if filename:match('^/') and file_exists(filename) then
    found = filename
  end

  -- 1. 用户指定目录（最高优先级）
  if not found and user_dir and user_dir ~= '' then
    found = search_in_dir(user_dir, filename, pkg_path)
  end

  -- 2. locate 命令
  if not found then
    found = search_via_locate(filename, pkg_path)
  end

  -- 3. 当前项目
  if not found then
    local root = get_project_root()
    found = search_in_dir(root, filename, pkg_path)
  end

  -- 4. 默认搜索目录
  if not found then
    for _, dir in ipairs(DEFAULT_SEARCH_DIRS) do
      found = search_in_dir(dir, filename, pkg_path)
      if found then
        break
      end
    end
  end

  -- 缓存结果（nil 也缓存为 false，避免重复搜索）
  search_cache[cache_key] = found or false
  return found
end

--- 解析单行日志，提取文件名、包路径、行号
--- 支持 Java 堆栈、通用 file:line、Python traceback 三种格式
---@param line string 日志行
---@return table|nil { filename, pkg_path, lnum, text }
local function parse_line(line)
  -- Java 堆栈格式：
  --   at com.xxx.LoginFilter.getToken(LoginFilter.java:137)
  --   at com.xxx.Outer$Inner.method(Outer.java:42)
  --   Caused by: java.lang.Exception at com.xxx.Foo.bar(Foo.java:10)
  local class_path, filename, lnum =
    line:match('at%s+([%w%.$]+)%.[%w_$]+%(([%w%.]+%.%w+):(%d+)%)')
  if filename and lnum then
    -- 从 class_path 提取包路径：com.xxx.LoginFilter → com/xxx
    -- com.xxx.LoginFilter$Inner → com/xxx
    local pkg = class_path:gsub('%.([%w$]+)$', '')
    pkg = pkg:gsub('%.', '/')
    return {
      filename = filename,
      pkg_path = pkg,
      lnum = tonumber(lnum),
      text = line,
    }
  end

  -- Python traceback: File "/path/to/file.py", line 42, in func
  local py_path, py_line =
    line:match('File%s+"([^"]+)"%s*,%s*line%s+(%d+)')
  if py_path and py_line then
    local fname = py_path:match('([^/]+)$') or py_path
    if file_exists(py_path) then
      return { filename = py_path, pkg_path = nil, lnum = tonumber(py_line), text = line }
    end
    return { filename = fname, pkg_path = nil, lnum = tonumber(py_line), text = line }
  end

  -- 通用格式：path/to/File.ext:42 或 /abs/path/File.ext:42
  local path_str, line_num =
    line:match('([%w%._/~$/-]+%.%w+):(%d+)')
  if path_str and line_num then
    local fname = path_str:match('([^/]+)$') or path_str
    if file_exists(path_str) then
      return { filename = path_str, pkg_path = nil, lnum = tonumber(line_num), text = line }
    end
    return { filename = fname, pkg_path = nil, lnum = tonumber(line_num), text = line }
  end

  return nil
end

--------------------------------------------------------------------------------
-- 公开接口（Public API）
--------------------------------------------------------------------------------

local M = {}

--- 从指定行范围提取堆栈，填充 quickfix 列表
---@param start_lnum number 起始行（1-based）
---@param end_lnum number 结束行（1-based）
---@param user_dir string|nil 用户指定的搜索目录
function M.jump_range(start_lnum, end_lnum, user_dir)
  -- 每次跳转清空缓存，保证文件路径是最新的
  search_cache = {}

  local lines = vim.api.nvim_buf_get_lines(0, start_lnum - 1, end_lnum, false)
  local qf_items = {}
  local found_count = 0

  for _, line in ipairs(lines) do
    local parsed = parse_line(line)
    if parsed then
      local full_path = find_source_file(parsed.filename, parsed.pkg_path, user_dir)
      if full_path then
        found_count = found_count + 1
        table.insert(qf_items, {
          filename = full_path,
          lnum = parsed.lnum,
          text = parsed.text,
          valid = 1,
        })
      else
        table.insert(qf_items, {
          filename = parsed.filename,
          lnum = parsed.lnum,
          text = parsed.text .. '  ← [未找到]',
          valid = 0,
        })
      end
    end
  end

  if #qf_items == 0 then
    vim.notify('[logjump] 未找到堆栈跟踪行', vim.log.levels.WARN)
    return
  end

  -- 填充 quickfix 列表并打开
  vim.fn.setqflist({}, 'r', {
    title = user_dir
        and string.format('[logjump] dir=%s  %d/%d found', user_dir, found_count, #qf_items)
        or string.format('[logjump] %d/%d found', found_count, #qf_items),
    items = qf_items,
  })
  vim.cmd('copen')

  -- 自动跳转到第一个有效项
  for i, item in ipairs(qf_items) do
    if item.valid == 1 then
      vim.cmd(tostring(i) .. 'cc')
      break
    end
  end

  local msg = string.format('[logjump] %d 条记录（%d 个已定位', #qf_items, found_count)
  if found_count < #qf_items then
    msg = msg .. string.format('，%d 个未找到', #qf_items - found_count)
  end
  msg = msg .. '）'
  vim.notify(msg, vim.log.levels.INFO)
end

--- 跳转：当前行（直接打开文件，不走 quickfix）
---@param user_dir string|nil 用户指定的搜索目录
function M.jump_line(user_dir)
  search_cache = {}

  local cur_line = vim.fn.getline('.')
  local parsed = parse_line(cur_line)

  if not parsed then
    vim.notify('[logjump] 当前行不是堆栈跟踪行', vim.log.levels.WARN)
    return
  end

  local full_path = find_source_file(parsed.filename, parsed.pkg_path, user_dir)
  if not full_path then
    vim.notify(
      string.format('[logjump] 未找到 %s（包路径: %s）', parsed.filename, parsed.pkg_path or 'N/A'),
      vim.log.levels.ERROR
    )
    return
  end

  -- 打开文件并跳转到指定行
  vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
  vim.api.nvim_win_set_cursor(0, { parsed.lnum, 0 })
  vim.cmd('normal! zz')
  vim.notify(
    string.format('[logjump] %s:%d', parsed.filename, parsed.lnum),
    vim.log.levels.INFO
  )
end

--- 跳转：整个 buffer
---@param user_dir string|nil 用户指定的搜索目录
function M.jump_buffer(user_dir)
  local last_line = vim.api.nvim_buf_line_count(0)
  M.jump_range(1, last_line, user_dir)
end

--- 跳转：可视选区
---@param user_dir string|nil 用户指定的搜索目录
function M.jump_selection(user_dir)
  local start_lnum = vim.fn.line('v')
  local end_lnum = vim.fn.line('.')
  if start_lnum > end_lnum then
    start_lnum, end_lnum = end_lnum, start_lnum
  end
  M.jump_range(start_lnum, end_lnum, user_dir)
end

return M
