-- keymaps.lua —— 通用键位（与具体插件无关；插件键位写在各自 plugins/*.lua）
local map = vim.keymap.set

-- 取消高亮搜索结果（normal 模式按 Esc；insert/visual 的 Esc 仍正常退回 normal，不触发此映射）
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = '取消高亮' })

-- 窗口切换（<C-hjkl>，配合 tmux 无缝切换见 tmuxp 章节）
map('n', '<C-h>', '<C-w>h', { desc = '左窗口' })
map('n', '<C-j>', '<C-w>j', { desc = '下窗口' })
map('n', '<C-k>', '<C-w>k', { desc = '上窗口' })
map('n', '<C-l>', '<C-w>l', { desc = '右窗口' })

-- 上下移动选中行 / 当前行
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = '下移选中' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = '上移选中' })

-- 粘贴时不污染默认寄存器（用 _ 黑洞）
map('x', '<leader>p', '"_dP', { desc = '粘贴不覆盖寄存器' })

-- 系统剪贴板：options.lua 已设 clipboard=unnamedplus，默认 y/p 即直通系统剪贴板，
-- 无需额外映射。（保留“复制全文”这个高频便捷键）
map('n', '<leader>yY', 'gg"+yG', { desc = '复制全文到剪贴板' })

-- 缩进保持选区
map('v', '<', '<gv')
map('v', '>', '>gv')

-- 编辑 / 重载配置 跟spacemacs保持一致
map('n', '<leader>fed', '<cmd>edit $MYVIMRC<CR>', { desc = '编辑 init.lua' })
map('n', '<leader>fer', '<cmd>source $MYVIMRC<CR>', { desc = '重载配置' })

-- 对齐 Spacemacs 的 SPC Tab
map('n', '<leader><Tab>', '<C-^>', { desc = '切到上一个 buffer' })


-- 退出
map('n', '<leader>qq', '<cmd>qa<CR>', { desc = '全部退出' })
