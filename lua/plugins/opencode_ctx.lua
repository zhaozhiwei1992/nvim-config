-- opencode_ctx.lua —— opencode 上下文桥（nvim → tmux pane）
-- 功能：通过 tmux send-keys 把当前文件 / 行号 / 选区发送到运行 opencode 的 pane，
--       并提供 :OpencodeLoad 用 tmuxp 拉起开发环境会话。
-- 说明：这不是外部插件，而是用 lazy.nvim 的 local plugin 机制（dir 指向 nvim 配置目录）
--       注册本地逻辑 + 键位，写法与 git.lua / editor.lua 等保持一致。

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

--------------------------------------------------------------------------------
-- lazy.nvim 规范
--------------------------------------------------------------------------------
return {
  {
    -- 本地插件：dir 指向 nvim 配置目录，lazy 把它当作一个本地 spec 加载
    dir = vim.fn.stdpath('config'),
    name = 'opencode-ctx',
    lazy = false,
    -- 仅当 tmux 可用且当前处于 tmux 会话内才启用，否则键位不注册（干净降级）
    cond = vim.fn.executable('tmux') == 1 and os.getenv('TMUX') ~= nil,

    -- 键位：<leader>o 前缀 = opencode（闭包引用 M，不依赖 _G 全局）
    keys = {
      { '<leader>ol', function() M.send_location() end, desc = 'opencode: 发送当前行' },
      { '<leader>of', function() M.send_file() end, desc = 'opencode: 发送文件路径' },
      { '<leader>os', function() M.send_selection() end, mode = 'v', desc = 'opencode: 发送选区' },
    },

    config = function()
      -- :OpencodeLoad [session] —— 通过 tmuxp 加载/附加开发环境会话
      -- 用法：:OpencodeLoad 或 :OpencodeLoad mywork
      -- 前置：~/.config/tmuxp/<session>.yaml 已定义（含 editor + opencode pane 布局）
      vim.api.nvim_create_user_command('OpencodeLoad', function(opts)
        local session = opts.args ~= '' and opts.args or DEFAULT_SESSION
        -- 异步执行 tmuxp load，避免阻塞 nvim；detach 让会话独立运行
        vim.system({ 'tmuxp', 'load', session }, { text = true }, function(obj)
          local msg = obj.code == 0
              and string.format('[opencode] tmuxp 会话 %s 已启动', session)
              or string.format('[opencode] tmuxp 失败: %s', obj.stderr or '')
          vim.schedule(function()
            vim.notify(msg, obj.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
          end)
        end)
      end, {
        nargs = '?',
        desc = '通过 tmuxp 加载开发环境会话',
        complete = function()
          -- 列举 ~/.config/tmuxp/*.yaml 作为补全
          local dir = vim.fn.expand('~/.config/tmuxp')
          local files = vim.fn.glob(dir .. '/*.yaml', false, true)
          local names = {}
          for _, f in ipairs(files) do
            table.insert(names, vim.fn.fnamemodify(f, ':t:r'))
          end
          return names
        end,
      })
    end,
  },
}
