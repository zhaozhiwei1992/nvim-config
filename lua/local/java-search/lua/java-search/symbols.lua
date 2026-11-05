-- symbols.lua —— treesitter 抽当前 buffer 的符号（精确、零索引成本，供 <leader><F12> 用）
-- 跨文件不走这里（逐文件解析几百个文件太慢），见 index.lua 的 rg 方案
local M = {}

local QUERY = [[
(class_declaration name: (identifier) @type.name)
(interface_declaration name: (identifier) @type.name)
(enum_declaration name: (identifier) @type.name)
(record_declaration name: (identifier) @type.name)
(annotation_type_declaration name: (identifier) @type.name)
(method_declaration name: (identifier) @method.name)
(constructor_declaration name: (identifier) @method.name)
(field_declaration declarator: (variable_declarator name: (identifier) @field.name))
]]

local KIND_LABEL = {
  ['type.name'] = 'type',
  ['method.name'] = 'method',
  ['field.name'] = 'field',
}

---@param bufnr? integer
---@return table[]|nil 每项 { name, kind, lnum, col }；parser 缺失返回 nil
function M.collect(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, 'java')
  if not ok_parser or not parser then return nil end
  local ok_parse, trees = pcall(function() return parser:parse(true) end)
  if not ok_parse or not trees or not trees[1] then return nil end

  local ok_query, query = pcall(vim.treesitter.query.parse, 'java', QUERY)
  if not ok_query then return nil end

  local root = trees[1]:root()
  local out = {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local capture = query.captures[id]
    local kind = KIND_LABEL[capture]
    if kind and node then
      local row, col = node:start()
      out[#out + 1] = {
        name = vim.treesitter.get_node_text(node, bufnr),
        kind = kind,
        lnum = row + 1,
        col = col + 1,
      }
    end
  end
  return out
end

return M
