-- opencode_ctx.lua —— opencode 上下文桥（lazy.nvim spec 包装）
-- 实际逻辑在 lua/lib/opencode_ctx.lua 模块中，本文件负责注册命令和键位。

-- 引入模块
local M = require('lib.opencode_ctx')

-- 文件级别创建用户命令（spec 文件被 lazy.nvim require 时即执行）
-- :OpencodeLoad [session] —— 通过 tmuxp 加载/附加开发环境会话
-- 用法：:OpencodeLoad 或 :OpencodeLoad mywork
-- 前置：~/.config/tmuxp/<session>.yaml 已定义（含 editor + opencode pane 布局）
vim.api.nvim_create_user_command('OpencodeLoad', function(opts)
  local session = opts.args ~= '' and opts.args or M.DEFAULT_SESSION
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
  },
}
