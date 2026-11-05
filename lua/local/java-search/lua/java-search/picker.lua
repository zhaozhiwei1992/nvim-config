-- picker.lua —— fzf-lua 承载：候选列表选择 + 文本搜索回落
-- 只在需要交互时 require('fzf-lua')（该插件 event=VeryLazy，第一次用到才加载）
local M = {}

---@return table
local function fzf()
  return require('fzf-lua')
end

--- 列表选择：行格式 "id<TAB>显示文本"，显示时隐藏 id 列
---@param items table[]
---@param render fun(item: table): string
---@param on_choice fun(item: table)
---@param opts? { prompt?: string }
function M.select(items, render, on_choice, opts)
  opts = opts or {}
  if #items == 0 then return end
  local lines, map = {}, {}
  for i, it in ipairs(items) do
    lines[#lines + 1] = i .. '\t' .. render(it)
    map[i] = it
  end
  fzf().fzf_exec(lines, {
    prompt = opts.prompt or 'Java> ',
    fzf_opts = {
      ['--delimiter'] = '\t',
      ['--with-nth'] = '2..',
    },
    actions = {
      default = function(selected)
        if not selected or not selected[1] then return end
        local id = tonumber(selected[1]:match('^(%d+)\t'))
        if id and map[id] then on_choice(map[id]) end
      end,
    },
  })
end

--- 项目内 .java 文本搜索（索引未命中时的兜底）
---@param word string
---@param opts? { cwd?: string }
function M.grep(word, opts)
  opts = opts or {}
  fzf().live_grep({
    search = word,
    cwd = opts.cwd,
    rg_opts = '--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -g "*.java" -e',
  })
end

return M
