-- comment2code.lua —— 本地插件 spec（逻辑在 lua/local/comment2code/，命令/键位在其 plugin/ 下）
return {
  {
    dir = vim.fn.stdpath('config') .. '/lua/local/comment2code',
    name = 'comment2code',
    lazy = false,
    -- 仅当 tmux 可用且当前处于 tmux 会话内才启用（传输依赖 tmux）
    cond = vim.fn.executable('tmux') == 1 and os.getenv('TMUX') ~= nil,
  },
}
