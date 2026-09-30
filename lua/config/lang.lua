-- config/lang.lua —— 语言工具清单集中管理（2026-09-21：Java / Go / Rust / Python / TS·JS / C·C++ / Lua）
-- 放在 config/ 下而非 plugins/，避免被 lazy.nvim 误判为插件 spec
-- 被 lua/plugins/lsp.lua 的 mason-tool-installer（ensure_installed）引用

local M = {}

-- 启用的 LSP 服务器清单（lsp.lua 里 vim.lsp.enable 按名加载 lsp/<name>.lua 作配置；
-- 打开对应文件类型才启动 client，不碰不改的语言零开销）
-- ⚠️ Java 不走这里：由 nvim-jdtls 插件 start_or_attach 接管（配置全在 ftplugin/java.lua）。
--    若把 'jdtls' 加进来会与插件双 client（两个 JVM 进程），禁止。
-- ⚠️ vue 不走 vtsls：.vue 是 SFC（template+script+style 三段），vtsls 解析不了，
--    必须用独立 client 'vue-language-server'（volar 2.x），见 lsp/vue-language-server.lua。
-- ✍️ 扩展新语言 = 5 步（nvim 原生不带任何 LSP，补全/跳转全靠服务器进程）：
--   1. 本清单 servers 加服务器名；2. 建 lsp/<name>.lua 写配置（cmd/filetypes/root_markers/settings）；
--   3. treesitter.lua parsers 加语言名（语法高亮/折叠）；4. formatter.lua 加映射 + 工具加进 M.mason_tools；
--   5.（上一步的工具若不在 PATH 或不在 mason 仓库，formatter.lua 里覆写 command 为绝对路径，
--      见 nginxfmt（venv）与 vue-language-server（独立 npm 目录）示例）
M.servers = {
  'gopls',         -- Go LSP（补全/跳转/诊断/重命名）
  'rust_analyzer', -- Rust LSP（rustup 组件装的，故不在下方 mason_tools 重复装，避免版本错乱）
  'basedpyright',  -- Python LSP（类型检查/诊断）
  'ruff',          -- Python lint + 格式化 LSP（与 basedpyright 互补，两者都开）
  'vtsls',         -- TypeScript / JavaScript LSP（只认 .ts/.js，不碰 .vue！）
  'vue-language-server', -- Vue SFC LSP（volar 2.x 手动装 @ ~/.local/share/vue-ls2，不在 mason 管、勿自动更新），见 lsp/vue-language-server.lua
  'clangd',        -- C / C++ LSP
  'lua_ls',        -- Lua LSP（编辑 nvim 配置 / 写插件时用）
}

-- mason 自动安装的工具（LSP + 格式化二进制；rust-analyzer/rustfmt 走 rustup 自带，不列）
M.mason_tools = {
  -- Java
  'jdtls',              -- Java LSP 引擎（eclipse.jdt.ls，mason 包自带 lombok.jar）
  'google-java-format', -- Java 格式化（conform 的 formatters_by_ft.java 用）
  -- Go
  'gopls',     -- Go LSP
  'goimports', -- Go 格式化：整理 import（排序/去重/补漏），保存时先跑
  'gofumpt',   -- Go 格式化：gofmt 严格版（对齐更整齐），gopls settings 也引用
  -- Python
  'basedpyright', -- Python LSP
  'ruff',         -- Python lint/格式化（诊断归 basedpyright，lint+格式归它）
  -- TS / JS / Vue
  'vtsls',    -- TS/JS LSP
  -- ⚠️ vue-language-server 不在 mason_tools：mason 只能装 volar 3.x，而 3.x 依赖
  --    client 侧 tsserver 代理（nvim 不支持），实测必卡死；此处用手动装的 volar 2.1.10
  --    （独立目录 ~/.local/share/vue-ls2，见 lsp/vue-language-server.lua 头注释的安装命令），
  --    不能列进 mason 自动更新，否则更新会拉回 3.x
  'prettier', -- TS/JS/json/yaml 格式化
  -- C / C++
  'clangd', -- C/C++ LSP
  -- Lua / TOML / shell（配置文件与脚本格式化）
  'lua-language-server', -- Lua LSP（= lua_ls）
  'stylua',              -- Lua 格式化
  'taplo',               -- TOML 格式化
  'shfmt',               -- shell 脚本格式化
}

return M
