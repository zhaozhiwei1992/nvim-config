-- opencode_ctx.lua —— opencode 上下文桥模块（nvim → tmux pane）
-- 位置：lua/lib/opencode_ctx.lua（自定义功能模块集中存放）
-- 被 lua/plugins/opencode_ctx.lua 引用，命令/键位在 spec 文件中注册。
-- 功能：通过 tmux send-keys 把当前文件 / 行号 / 选区发送到运行 opencode 的 pane。

--------------------------------------------------------------------------------
-- 配置区（Configurable Section）
--------------------------------------------------------------------------------

-- 如果自动查找失败，回退使用的 Pane 编号
-- 可通过 `tmux list-panes` 查看，通常是 .0 或 .1（. + pane_index）
local FALLBACK_PANE = '.1'

-- 开发环境默认 tmuxp 会话名（:OpencodeLoad 不带参数时使用）
-- 需事先准备 ~/.config/tmuxp/<DEFAULT_SESSION>.yaml
local DEFAULT_SESSION = 'dev'

--------------------------------------------------------------------------------
-- 私有函数（Private Functions）
--------------------------------------------------------------------------------

--- 查找运行 opencode 的 tmux pane
--- 优先用进程名匹配，找不到则回退 FALLBACK_PANE
---@return string tmux pane id，形如 ".1"
local function find_opencode_pane()
  local handle =
    io.popen('tmux list-panes -F "#{pane_index} #{pane_current_command}" 2>/dev/null')
  if not handle then
    return FALLBACK_PANE
  end

  local result = FALLBACK_PANE
  for line in handle:lines() do
    -- 匹配当前 pane 运行的命令是否包含 "opencode"
    if line:match('opencode') then
      local index = line:match('^(%d+)')
      result = '.' .. index
      break
    end
  end

  handle:close()
  return result
end

--- 向运行 opencode 的 tmux pane 发送文本
--- 流程：Escape→Normal，C-u 清空输入框残留，i→Insert，-l 字面量发送文本，Enter 提交
---@param text string 要发送的内容
local function send_to_tmux(text)
  local pane = find_opencode_pane()
  -- -l：按字面量（Literal）发送，防止 ! $ 等被 shell 解析
  vim.fn.system({ 'tmux', 'send-keys', '-t', pane, 'Escape' })
  vim.fn.system({ 'tmux', 'send-keys', '-t', pane, 'C-u' }) -- 清空输入框残留
  vim.fn.system({ 'tmux', 'send-keys', '-t', pane, 'i' })
  vim.fn.system({ 'tmux', 'send-keys', '-t', pane, '-l', text })
  -- 最好不要敲回车，可能还有别的内容要补充一起发给ai。
  -- vim.fn.system({ 'tmux', 'send-keys', '-t', pane, 'Enter' })
  vim.notify('[opencode] 已发送到 pane ' .. pane, vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- 公开接口（Public API，M 表 + 闭包引用，无需 _G 全局污染）
--------------------------------------------------------------------------------

local M = {}

-- 暴露默认会话名，供 spec 文件注册 :OpencodeLoad 命令时使用
M.DEFAULT_SESSION = DEFAULT_SESSION

--- 发送当前文件路径 + 光标行号（如 /path/file.lua:42）
function M.send_location()
  local filepath = vim.fn.expand('%:p')
  local linenr = vim.fn.line('.')
  send_to_tmux(string.format('%s:%d', filepath, linenr))
end

--- 发送当前文件的绝对路径（opencode 会读取该文件内容）
function M.send_file()
  local filepath = vim.fn.expand('%:p')
  send_to_tmux('@' .. filepath)
end

--- 发送可视模式选中的文本（附带来源标签 @file:start-end）
function M.send_selection()
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local text_content = table.concat(lines, '\n')

  -- 上下文标签，便于 opencode 识别来源（opencode 用 @file 引用文件）
  local filepath = vim.fn.expand('%:p')
  local tag = string.format('@%s:%d-%d\n', filepath, start_line, end_line)
  send_to_tmux(tag .. text_content)
end

return M
