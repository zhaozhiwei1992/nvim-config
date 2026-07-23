-- opencode_ctx/plugin/init.lua —— 命令 + 键位注册（插件加载时自动 source）
local M = require('opencode_ctx')

-- :OpencodeLoad [session] —— 通过 tmuxp 加载/附加开发环境会话
vim.api.nvim_create_user_command('OpencodeLoad', function(opts)
  local session = opts.args ~= '' and opts.args or M.DEFAULT_SESSION
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
    local dir = vim.fn.expand('~/.config/tmuxp')
    local files = vim.fn.glob(dir .. '/*.yaml', false, true)
    local names = {}
    for _, f in ipairs(files) do
      table.insert(names, vim.fn.fnamemodify(f, ':t:r'))
    end
    return names
  end,
})

-- 键位：<leader>o 前缀 = opencode
vim.keymap.set('n', '<leader>ol', function() M.send_location() end, { desc = 'opencode: 发送当前行' })
vim.keymap.set('n', '<leader>of', function() M.send_file() end, { desc = 'opencode: 发送文件路径' })
vim.keymap.set('v', '<leader>os', function() M.send_selection() end, { desc = 'opencode: 发送选区' })
