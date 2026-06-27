-- autocmds.lua —— 自动命令
local au = vim.api.nvim_create_autocmd
local grp = vim.api.nvim_create_augroup

-- 高亮 yank 区域
au('TextYankPost', {
  callback = function()
    vim.hl.on_yank()
  end,
  group = grp('YankHighlight', {}),
})

-- 保存时自动去除行尾空白（对齐 vimrc \rb 习惯）
-- 例外：markdown 行尾两个空格是「强制换行」语义，删了会破坏排版 → 跳过
au('BufWritePre', {
  pattern = '*',
  callback = function(ev)
    if vim.bo[ev.buf].filetype == 'markdown' then
      return
    end
    local saved = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(saved)
  end,
  group = grp('TrimTrailingWS', {}),
})

-- 终端窗口关相对行号
au('TermOpen', {
  callback = function()
    vim.opt_local.relativenumber = false
  end,
  group = grp('TermOpts', {}),
})

-- bigfile 策略：大文件关掉 syntax/fold/undo 等重特性，防 nvim 卡顿
au({ 'BufReadPre' }, {
  group = grp('BigFile', {}),
  pattern = '*',
  callback = function(ev)
    local ok, stats = pcall(vim.uv.fs_stat, ev.match)
    if ok and stats and stats.size > 1024 * 1024 then -- > 1MB
      vim.b.bigfile = true
      vim.opt_local.syntax = ''
      vim.opt_local.foldmethod = 'manual'
      vim.opt_local.undolevels = -1
    end
  end,
})
