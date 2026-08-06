-- comment2code.lua —— 注释驱动代码生成（nvim + pi + tmux）
-- 位置：lua/local/comment2code/lua/comment2code/init.lua（本地插件，逻辑单文件）
-- 被 lua/plugins/comment2code.lua 引用，命令/键位在 lua/local/comment2code/plugin/init.lua 注册。
-- 功能：@ai 注释 → treesitter 抓上下文 → tmux send-keys 发 prompt 给 pi -p
--       → wait-for 同步等 pi 跑完 → 读输出文件 → 清洗回写当前 buffer。
-- 不依赖 LSP / cmp / Copilot。
-- 设计文档：~/workspace/项目管理/开发文档/插件开发/nvim/002_nvim代码提示插件开发文档.org
-- 使用前提：nvim 与 agent shell 在同一 tmux 会话，同窗口至少有一个 shell pane。

--------------------------------------------------------------------------------
-- 配置区（Configurable Section）
--------------------------------------------------------------------------------

local TIMEOUT = 180                 -- pi 单次生成超时（秒），由 timeout 命令兜底
local ANCHOR_LOOKBACK = 3           -- 光标向上多少行内找 @ai 锚点
local BEFORE_LINES = 30             -- 锚点前上下文行数
local AFTER_LINES = 10              -- 锚点后上下文行数
local FALLBACK_METHOD_LINES = 200   -- treesitter 失效时的方法上下文行数
local MAX_IMPORT_SCAN = 100         -- import 区扫描行数上限
local MAX_LOGS = 20                 -- 日志保留条数（超出按 mtime 滚动删除）

-- 可作 agent pane 的 shell（pane_current_command 命中这些才发键）
local SHELL_CMDS = { zsh = true, bash = true, fish = true, sh = true, dash = true, tcsh = true }

-- filetype → 语言展示名（Prompt 注入）
local LANG_NAMES = {
  java = 'Java', python = 'Python', typescript = 'TypeScript',
  javascript = 'JavaScript', tsx = 'TypeScript React', go = 'Go',
  rust = 'Rust', lua = 'Lua', vim = 'Vimscript', sh = 'Shell', bash = 'Shell',
}

-- filetype → 行注释前缀（TODO 前缀注入）
local COMMENT_PREFIX = {
  java = '//', typescript = '//', javascript = '//', tsx = '//',
  go = '//', rust = '//', c = '//', cpp = '//',
  python = '#', lua = '--', sh = '#', bash = '#', vim = '"',
}

-- filetype → treesitter 函数节点类型（抓“当前方法”）
local TS_NODES = {
  java = { 'method_declaration', 'constructor_declaration' },
  python = { 'function_definition', 'class_definition' },
  typescript = { 'function_declaration', 'method_definition', 'arrow_function', 'generator_function_declaration' },
  javascript = { 'function_declaration', 'method_definition', 'arrow_function', 'generator_function_declaration' },
  tsx = { 'function_declaration', 'method_definition', 'arrow_function', 'generator_function_declaration' },
  go = { 'function_declaration', 'method_declaration' },
  rust = { 'function_item' },
  lua = { 'function_declaration', 'function_definition' },
}

-- filetype → import 行匹配（go 块状 import 单独处理）
local IMPORT_PATTERNS = {
  java = { '^%s*import%s+[%w%.%*]+%s*;' },
  python = { '^%s*from%s+[%w_%.]+%s+import', '^%s*import%s+[%w_%.]+' },
  typescript = { '^%s*import%s+.*from%s+["\x27]', '^%s*import%s+["\x27]' },
  javascript = { '^%s*import%s+.*from%s+["\x27]', '^%s*import%s+["\x27]' },
  tsx = { '^%s*import%s+.*from%s+["\x27]', '^%s*import%s+["\x27]' },
  go = { '^%s*import%s' },
  rust = { '^%s*use%s+' },
  lua = { '^%s*local%s+[%w_]+%s*=%s*require' },
}

-- Prompt 模板：{{lang}}/{{todo_prefix}} 在 build_prompt 里按 filetype 注入
local PROMPT_TEMPLATE = [[你是一个资深 %s 工程师。
请根据以下上下文，在光标位置生成代码块。

【导入】
%s

【当前方法】
%s

【光标前】
%s

【光标后】
%s

【锚点注释】
%s

规则：
1. 仅输出光标处所需代码
2. 遇到方法体 `}` 立即结束
3. 不超过 40 行
4. 不重复已有代码
5. 不写解释
6. 不写 ``` 代码块
7. 若上下文不足，只输出：
   %s <原因>]]

--------------------------------------------------------------------------------
-- 状态区（上次生成结果，供 <leader>ar / <leader>ac / <leader>at 使用）
--------------------------------------------------------------------------------

local M = {}
M.state = {
  busy = false,
  last_prompt = nil,
  last_raw = '',
  last_cleaned = '',
  last_range = nil,       -- 上次插入的行区间（0-based），供撤销
  last_anchor_line = nil, -- 上次插入的锚点行（1-based），供重新生成
}

local function notify(msg, level)
  vim.notify('[comment2code] ' .. msg, level or vim.log.levels.INFO)
end

--- 落盘日志：prompt / raw output / cleaned output
--- 注意：writefile 会把列表元素内的 \n 写成 NUL，必须按行拆分后再写
local function log_run(prompt, raw, cleaned)
  local dir = vim.fn.stdpath('cache') .. '/ai'
  vim.fn.mkdir(dir, 'p')
  local f = dir .. '/' .. os.date('%Y%m%d-%H%M%S') .. '.log'
  local parts = { '===== prompt =====' }
  vim.list_extend(parts, vim.split(prompt, '\n'))
  vim.list_extend(parts, { '', '===== raw output =====' })
  vim.list_extend(parts, vim.split(raw, '\n'))
  vim.list_extend(parts, { '', '===== cleaned =====' })
  vim.list_extend(parts, vim.split(cleaned, '\n'))
  vim.list_extend(parts, { '' })
  vim.fn.writefile(parts, f)
  -- 滚动清理：只保留最近 MAX_LOGS 个日志
  local entries = {}
  for _, fl in ipairs(vim.fn.glob(dir .. '/*.log', false, true)) do
    entries[#entries + 1] = { file = fl, mtime = vim.fn.getftime(fl) }
  end
  table.sort(entries, function(a, b)
    return a.mtime > b.mtime
  end)
  for i = MAX_LOGS + 1, #entries do
    pcall(vim.fn.delete, entries[i].file)
  end
  return f
end

--- 删除本次运行产生的临时文件（prompt/out 内容已全量进入 log，无需保留）
local function cleanup_temp_files(prompt_file, out_file)
  for _, f in ipairs({ prompt_file, out_file }) do
    if f and vim.fn.filereadable(f) == 1 then
      pcall(vim.fn.delete, f)
    end
  end
end

--------------------------------------------------------------------------------
-- Transport：pane 发现 + 发送 + 同步等待（tmux 唯一 IPC）
--------------------------------------------------------------------------------

--- 查找 agent pane：$NVIM_AI_PANE > 同窗口非活动 shell pane > 同窗口任意 shell pane
--- 绝不向 nvim / 交互式 pi pane 发键（pane_current_command 必须命中 SHELL_CMDS）
function M.find_agent_pane()
  local override = os.getenv('NVIM_AI_PANE')
  if override and override ~= '' then
    return override
  end
  local cur = os.getenv('TMUX_PANE')
  if not cur then
    return nil
  end
  local win = vim.fn.system({ 'tmux', 'display-message', '-p', '-t', cur, '#{session_name}:#{window_index}' })
  win = win:gsub('%s+$', '')
  if win == '' then
    return nil
  end
  local out = vim.fn.system({
    'tmux', 'list-panes', '-t', win,
    '-F', '#{pane_index} #{pane_current_command} #{pane_active} #{pane_id}',
  })
  local fallback = nil
  for line in out:gmatch('[^\r\n]+') do
    local idx, cmd, active, pid = line:match('^(%d+) (%S+) (%d) (%S+)$')
    if idx and SHELL_CMDS[cmd] and pid ~= cur then
      local pane = win .. '.' .. idx
      if active == '0' then
        return pane -- 优先非活动 shell pane
      end
      fallback = fallback or pane
    end
  end
  return fallback
end

--- 发送 prompt 并同步等待 pi 跑完，返回输出文件路径；失败返回 nil
--- 命令：cat prompt | timeout 180 pi -p -nt --no-session -ne -ns -np -nc > out; tmux wait-for -S ai_<ts>
---  -p：非交互 stdin→stdout（必须，否则进 TUI）
---  -nt：禁用工具，纯生成；--no-session：不落会话文件
---  -ne -ns -np -nc：禁用扩展/skill/prompt 模板/上下文文件，保证上下文由 nvim 精确控制
local function send_to_pi(prompt)
  local ts = tostring(os.time())
  local dir = vim.fn.stdpath('cache') .. '/ai'
  vim.fn.mkdir(dir, 'p')
  local prompt_file = dir .. '/prompt_' .. ts .. '.txt'
  local out_file = dir .. '/out_' .. ts .. '.txt'
  vim.fn.writefile(vim.split(prompt, '\n'), prompt_file)

  local pane = M.find_agent_pane()
  if not pane then
    notify('未找到 agent pane（同窗口需有一个 zsh/bash/fish shell pane，或用 $NVIM_AI_PANE 指定）', vim.log.levels.WARN)
    cleanup_temp_files(prompt_file, nil)
    return nil
  end

  local cmd = string.format(
    'cat %s | timeout %d pi -p -nt --no-session -ne -ns -np -nc > %s; tmux wait-for -S ai_%s',
    vim.fn.shellescape(prompt_file), TIMEOUT, vim.fn.shellescape(out_file), ts
  )
  vim.fn.system({ 'tmux', 'send-keys', '-t', pane, cmd, 'Enter' })
  vim.fn.system({ 'tmux', 'wait-for', 'ai_' .. ts }) -- 同步阻塞，pi 跑完或超时才返回
  return out_file, prompt_file
end

--- 读取 pi 输出文件（timeout 被杀时也能拿到部分输出）
local function read_pi_output(out_file)
  if vim.fn.filereadable(out_file) ~= 1 then
    return ''
  end
  return table.concat(vim.fn.readfile(out_file, '', 2000), '\n')
end

--------------------------------------------------------------------------------
-- Context Builder：方法（primary）/ import（secondary）/ 光标上下文（tertiary）/ 锚点
--------------------------------------------------------------------------------

local function first_non_ws_col(line)
  local c = line:find('%S')
  return c and c - 1 or 0
end

--- treesitter 找包含锚点的函数节点，返回 [起始行, 结束行]（0-based）；找不到返回 nil
--- 锚点注释可能在方法体上方（doc 示例写法），所以先试锚点行、再试锚点下一行
local function ts_function_range(buf, anchor_line)
  local types = TS_NODES[vim.bo[buf].filetype]
  if not types then
    return nil
  end
  for _, row in ipairs({ anchor_line - 1, anchor_line }) do -- 0-based 行
    local text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, first_non_ws_col(text) } })
    if ok and node then
      while node do
        for _, want in ipairs(types) do
          if node:type() == want then
            return node:start(), node:end_()
          end
        end
        node = node:parent()
      end
    end
  end
  return nil
end

local function get_lines(buf, srow, erow)
  -- srow/erow 均为 1-based（erow 含），自动 clamp
  local count = vim.api.nvim_buf_line_count(buf)
  if srow < 1 then
    srow = 1
  end
  if erow > count then
    erow = count
  end
  if srow > erow then
    return {}
  end
  return vim.api.nvim_buf_get_lines(buf, srow - 1, erow, false)
end

--- 抓 import 区（buffer 前 MAX_IMPORT_SCAN 行），go 块状 import 单独处理
local function collect_imports(buf, ft)
  local pats = IMPORT_PATTERNS[ft]
  if not pats then
    return {}
  end
  local lines = get_lines(buf, 1, math.min(MAX_IMPORT_SCAN, vim.api.nvim_buf_line_count(buf)))
  local out, in_go_block = {}, false
  for _, l in ipairs(lines) do
    if ft == 'go' and in_go_block then
      if l:match('^%s*%)') then
        in_go_block = false
      elseif l:match('^%s*"[-%w%./]+"') then
        out[#out + 1] = l
      end
    elseif l:match('^%s*import%s*%(.*%)') and ft == 'go' and not l:match('%)%s*$') then
      in_go_block = true
      out[#out + 1] = l
    else
      for _, p in ipairs(pats) do
        if l:match(p) then
          out[#out + 1] = l
          break
        end
      end
    end
    if #out >= 30 then
      break
    end
  end
  return out
end

--- 从锚点注释行提取任务描述：剥掉注释标记与 @ai
local function extract_task(line)
  local s = line:gsub('@ai', '')
  s = s:gsub('^%s*[%s/#*%-"`]+', '')
  s = s:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  return s
end

--- 构建上下文。anchor_override 供 visual 选区用（{ line=1-based, text=任务文本 }）
function M.build_context(buf, anchor_override)
  local ft = vim.bo[buf].filetype
  if ft == '' then
    notify('无法识别文件类型（filetype 为空），跳过', vim.log.levels.WARN)
    return nil
  end

  local anchor_line, anchor_text
  if anchor_override then
    anchor_line, anchor_text = anchor_override.line, anchor_override.text
  else
    local cur = vim.fn.line('.')
    for l = cur, math.max(1, cur - ANCHOR_LOOKBACK), -1 do
      local text = get_lines(buf, l, l)[1] or ''
      if text:match('@ai') then
        anchor_line, anchor_text = l, text
        break
      end
    end
    if not anchor_line then
      notify('未找到 @ai 锚点（当前行或向上 ' .. ANCHOR_LOOKBACK .. ' 行内）', vim.log.levels.WARN)
      return nil
    end
  end

  -- primary：treesitter 当前方法；fallback：buffer 前 FALLBACK_METHOD_LINES 行
  local sr, er = ts_function_range(buf, anchor_line)
  local method
  if sr then
    method = table.concat(get_lines(buf, sr + 1, er + 1), '\n')
  else
    method = table.concat(get_lines(buf, 1, FALLBACK_METHOD_LINES), '\n')
  end

  local imports = collect_imports(buf, ft)
  local before = table.concat(get_lines(buf, anchor_line - BEFORE_LINES, anchor_line - 1), '\n')
  local after = table.concat(get_lines(buf, anchor_line + 1, anchor_line + AFTER_LINES), '\n')

  return {
    lang = LANG_NAMES[ft] or ft,
    todo_prefix = (COMMENT_PREFIX[ft] or '//') .. ' TODO:',
    imports = #imports > 0 and table.concat(imports, '\n') or '（无）',
    method = method ~= '' and method or '（无）',
    before = before ~= '' and before or '（无）',
    after = after ~= '' and after or '（无）',
    anchor = extract_task(anchor_text),
    anchor_line = anchor_line,
  }
end

--------------------------------------------------------------------------------
-- Prompt Builder
--------------------------------------------------------------------------------

function M.build_prompt(ctx)
  return string.format(PROMPT_TEMPLATE, ctx.lang, ctx.imports, ctx.method, ctx.before, ctx.after, ctx.anchor, ctx.todo_prefix)
end

--------------------------------------------------------------------------------
-- Writer：清洗 + 回写 + 撤销
--------------------------------------------------------------------------------

--- 清洗：去 ``` 围栏行（内容保留）→ 去首尾空行 → 截断到第一个非缩进 }（方法体收尾留给用户）
function M.clean(raw)
  local lines = vim.split(raw, '\n')
  local out = {}
  for _, l in ipairs(lines) do
    if not l:match('^%s*```') then
      out[#out + 1] = l
    end
  end
  while #out > 0 and out[1]:match('^%s*$') do
    table.remove(out, 1)
  end
  while #out > 0 and out[#out]:match('^%s*$') do
    table.remove(out)
  end
  for i = 1, #out do
    if out[i]:match('^}%s*$') then
      for j = #out, i, -1 do
        table.remove(out, j)
      end
      break
    end
  end
  return table.concat(out, '\n')
end

--- 在锚点行之后插入代码（行级插入，光标移到插入块末尾），返回插入区间（0-based）
--- 必须用 nvim_buf_set_lines：set_text 在行内/行尾做多行插入会把相邻行内容拼接到插入块
function M.insert(buf, anchor_line, code)
  local lines = vim.split(code, '\n')
  local insert_at = anchor_line -- 1-based 锚点行之后 = 0-based 索引恰好等于锚点行号
  vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, lines)
  local range = { start = insert_at, finish = insert_at + #lines - 1 }
  vim.api.nvim_win_set_cursor(0, { anchor_line + #lines, 0 })
  return range
end

--- 撤销上次插入：删除记录的行区间
local function clear_last()
  local r = M.state.last_range
  if not r then
    notify('没有可撤销的上次插入', vim.log.levels.WARN)
    return
  end
  pcall(vim.api.nvim_buf_set_lines, 0, r.start, r.finish + 1, false, {})
  M.state.last_range = nil
  notify('已撤销上次插入')
end

--------------------------------------------------------------------------------
-- 主流程
--------------------------------------------------------------------------------

local function run(prompt, anchor_line)
  M.state.busy = true
  local out_file, prompt_file = send_to_pi(prompt)
  if not out_file then
    M.state.busy = false
    return false
  end
  local raw = read_pi_output(out_file)
  cleanup_temp_files(prompt_file, out_file) -- 读完即删，内容已进 log
  local cleaned = M.clean(raw)
  M.state.busy = false

  M.state.last_prompt = prompt
  M.state.last_raw = raw
  M.state.last_cleaned = cleaned
  M.state.last_anchor_line = anchor_line

  local logfile = log_run(prompt, raw, cleaned)

  if raw == '' then
    notify('pi 无输出（可能超时或模型错误），日志 ' .. logfile, vim.log.levels.WARN)
    return false
  end
  -- 规则 7：模型判定上下文不足 → 仅提示，不插入
  local first_line = cleaned:match('^[^\n]*') or ''
  if first_line:match('TODO') then
    notify('模型判定上下文不足：' .. cleaned:gsub('%s+', ' ') .. '（未插入，日志 ' .. logfile .. '）', vim.log.levels.WARN)
    return false
  end
  if cleaned == '' then
    notify('输出为空，未插入（日志 ' .. logfile .. '）', vim.log.levels.WARN)
    return false
  end

  M.state.last_range = M.insert(vim.api.nvim_get_current_buf(), anchor_line, cleaned)
  notify(string.format('已插入 %d 行代码（锚点下 %d 行，日志 %s）', #vim.split(cleaned, '\n'), anchor_line, logfile))
  return true
end

--- <leader>ai：锚点 @ai 注释下生成代码
function M.generate()
  if M.state.busy then
    notify('上一次生成尚未完成，请稍候', vim.log.levels.WARN)
    return
  end
  local ctx = M.build_context(vim.api.nvim_get_current_buf())
  if not ctx then
    return
  end
  run(M.build_prompt(ctx), ctx.anchor_line)
end

--- visual + <leader>ai：选区作为任务描述，插入到选区之后
function M.generate_visual()
  if M.state.busy then
    notify('上一次生成尚未完成，请稍候', vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local start_l = vim.fn.line('v')
  local end_l = vim.fn.line('.')
  if start_l > end_l then
    start_l, end_l = end_l, start_l
  end
  local sel = table.concat(vim.api.nvim_buf_get_lines(buf, start_l - 1, end_l, false), '\n')
  local ctx = M.build_context(buf, { line = end_l, text = sel })
  if not ctx then
    return
  end
  run(M.build_prompt(ctx), ctx.anchor_line)
end

--- <leader>ar：用上次的 prompt 原样重新生成（不重建上下文）
function M.regenerate()
  if not M.state.last_prompt then
    notify('还没有上次的 prompt，先执行 <leader>ai', vim.log.levels.WARN)
    return
  end
  if M.state.busy then
    notify('上一次生成尚未完成，请稍候', vim.log.levels.WARN)
    return
  end
  run(M.state.last_prompt, M.state.last_anchor_line or vim.fn.line('.'))
end

--- <leader>ac：撤销上次插入
function M.clear()
  clear_last()
end

--- <leader>at：scratch buffer 查看上次 prompt
function M.show_prompt()
  if not M.state.last_prompt then
    notify('还没有 prompt，先执行 <leader>ai', vim.log.levels.WARN)
    return
  end
  vim.cmd('enew')
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.filetype = 'markdown'
  vim.api.nvim_buf_set_name(0, 'comment2code-prompt')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(M.state.last_prompt, '\n'))
  vim.keymap.set('n', 'q', '<cmd>bwipeout<CR>', { buffer = true })
  notify('上次 prompt 已打开（日志中也有完整记录）')
end

return M
