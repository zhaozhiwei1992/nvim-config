-- clipboard-path/init.lua —— 把当前文件的各种路径塞进系统剪贴板
local M = {}

-- 把任意字符串写入 + 寄存器并提示
-- @param value string  要复制的文本，nil/空串时告警
-- @param label string  通知前缀
function M.copy(value, label)
  if value == nil or value == '' then
    vim.notify(label .. ': 当前没有可复制的路径', vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', value)
  vim.fn.setreg('"', value) -- 同步默认寄存器，p 也能直接贴
  vim.notify(label .. ': ' .. value, vim.log.levels.INFO)
end

-- 各类路径取值
function M.abs_path() return vim.fn.expand('%:p')  end
function M.rel_path() return vim.fn.expand('%')    end
function M.dir()      return vim.fn.expand('%:p:h') end
function M.filename() return vim.fn.expand('%:t')  end
function M.line_ref() return vim.fn.expand('%:p') .. ':' .. vim.fn.line('.') end

return M