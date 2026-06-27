-- options.lua —— 融合 vim 老习惯 + 现代 sane defaults
local o = vim.opt

-- 基础显示
o.number = true -- 行号
o.relativenumber = true -- 相对行号（配合 5j 这类跳转）
o.cursorline = true -- 高亮当前行
o.signcolumn = 'yes' -- 永久 signcolumn，避免抖动（LSP 诊断会撑开）
o.showmode = false -- 由 statusline 显示模式

-- 缩进
o.expandtab = true -- tab → 空格
o.tabstop = 4
o.shiftwidth = 4
o.smarttab = true
o.autoindent = true
o.smartindent = true

-- 搜索
o.ignorecase = true -- 忽略大小写...
o.smartcase = true -- ...除非输入含大写

-- 编辑体验
o.splitright = true -- 新窗口在右侧
o.splitbelow = true -- 新窗口在下方
o.termguicolors = true -- 24bit 颜色
o.updatetime = 250 -- 触发 CursorHold/swap 写盘更快
o.timeoutlen = 300 -- which-key 弹出更快
o.completeopt = { 'menu', 'menuone', 'noselect' }
o.scrolloff = 8 -- 光标距屏幕边至少留 8 行
o.sidescrolloff = 8
o.clipboard = 'unnamedplus' -- 和系统剪贴板互通（需 xclip/wl-clipboard）

-- 撤销持久化（关掉 nvim 也能 undo）
o.undofile = true

o.wrap = false
o.breakindent = true
