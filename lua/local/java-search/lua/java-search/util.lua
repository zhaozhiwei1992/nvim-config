-- util.lua —— 项目根探测 / cache 路径 / notify / vim.system 同步封装
local M = {}

-- 项目根标记：与 jdtls 时代 ftplugin 里那套保持一致，避免根目录漂移
local BUILD_MARKERS = { 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle' }
local VCS_MARKERS = { '.git', '.hg', '.svn' }

--- 当前 buffer 所属项目根（绝对路径，无尾斜杠）
--- 优先级：VCS 根 > 最外层构建文件根 > 文件所在目录
---   为什么不是最近一个 pom：多模块 maven（父 pom + 子模块 pom）如果停在子模块，
---   兄弟模块的类就搜不到，gd 直接失效；单仓单一 .git 时用 .git 根最稳。
---@param bufnr? integer
---@return string
function M.root(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  local vcs = vim.fs.root(bufnr, VCS_MARKERS)
  if vcs then return vim.fs.normalize(vcs) end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local start = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  local best, cur, depth = nil, start, 0
  while cur and depth < 10 do
    for _, m in ipairs(BUILD_MARKERS) do
      if vim.fn.filereadable(cur .. '/' .. m) == 1 then best = cur end
    end
    local parent = vim.fs.dirname(cur)
    if parent == cur then break end
    cur, depth = parent, depth + 1
  end
  if best then return vim.fs.normalize(best) end
  return vim.fs.normalize(start)
end

--- 短哈希，用作 cache 文件名
---@param s string
---@return string
function M.hash(s)
  return vim.fn.sha256(s):sub(1, 16)
end

---@return string
function M.cache_dir()
  return vim.fs.joinpath(vim.fn.stdpath('cache'), 'java-search')
end

---@param msg string
---@param level? integer vim.log.levels
function M.notify(msg, level)
  vim.notify('[java-search] ' .. msg, level or vim.log.levels.INFO)
end

--- 同步跑一个命令（P0 用同步：索引构建有缓存，命中时不调用）
---@param cmd string[]
---@param opts? table vim.system 选项（cwd / stdin / text）
---@return { code: integer, stdout: string, stderr: string }
function M.run(cmd, opts)
  opts = vim.tbl_extend('force', { text = true }, opts or {})
  local ok, obj = pcall(vim.system, cmd, opts)
  if not ok then
    return { code = -1, stdout = '', stderr = tostring(obj) }
  end
  local res = obj:wait()
  return { code = res.code or -1, stdout = res.stdout or '', stderr = res.stderr or '' }
end

--- 读文件的第 N 行（1-based）；用于把索引里的截断签名补全成整行
---@param path string
---@param lnum integer
---@return string|nil
function M.read_line(path, lnum)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local i = 0
  for line in fd:lines() do
    i = i + 1
    if i == lnum then
      fd:close()
      return line
    end
  end
  fd:close()
  return nil
end

---@return boolean
function M.has_rg()
  return vim.fn.executable('rg') == 1
end

return M
