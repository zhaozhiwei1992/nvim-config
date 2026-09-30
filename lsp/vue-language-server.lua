-- lsp/vue-language-server.lua —— Vue SFC 语言服务（Volar）独立 client 配置
-- 作用：.vue 文件（template+script+style 三段）的补全/跳转/悬停/重构。
-- 本配置被 lua/config/lang.lua 的 servers 清单按名加载（vim.lsp.enable 机制），
-- 文件名必须等于服务器名：vue-language-server.lua。

-- ⚠️ 为什么手动装 volar 2.1.10 到独立目录、不走 mason（重要背景，改配置前必读）：
--   1. Volar 3.x（mason 默认）依赖 client 端实现 tsserver proxy：server 收到请求后
--      反手发 tsserver/request（_vue:* 共 14+ 命令）等 client 响应，nvim 没有这套
--      实现 → 所有请求永久 pending（诊断/跳转全卡死，lsp.log 可见 $/cancelRequest），
--      实测 node22/26 均如此，与 nvim 配置无关，属协议层面无解。
--   2. Volar 2.x 默认 hybridMode 同样依赖 tsserver；但 2.x 有 isolated 模式：
--      init_options.vue.hybridMode=false → server 用内置 TS 独立干活，不需代理。
--      这是 nvim 唯一可行路线。
--   3. 版本为什么选 2.1.10：2.2.x 依赖 git 源包（npm12 禁）+ Nexus 缺 tarball，
--      装不上；2.1.x 依赖链干净，实测 Vue 2.5.2 老项目 template→methods 跳转/hover 正常。
--
-- 安装 / 重装命令（独立目录 ~/.local/share/vue-ls2，随时可整目录重来）：
--   mkdir -p ~/.local/share/vue-ls2
--   npm install --prefix ~/.local/share/vue-ls2 @vue/language-server@2.1.10
--   npm install --prefix ~/.local/share/vue-ls2 typescript@^5
-- 注意：为此没把 'vue-language-server' 放进 lang.lua 的 mason_tools，
--   mason 自动更新会把目录拉回 3.x，禁止加回。

-- ⚠️ 兼容边界（预期行为，不是故障）：vue-demo 是 Vue 2.5.2（2017），volar 官方
--   只保证 Vue 2.7+/3；实测 Options API 的 template→methods 定义跳转、hover 正常，
--   但 Vue2 高级特性（.sync/.native/插槽类型推断）与跨文件类型推断可能缺失。

return {
  -- 绝对路径指向独立安装的 2.1.10（mason 的 3.x 不能用于 nvim，见上）
  cmd = {
    vim.fn.expand('~/.local/share/vue-ls2/node_modules/.bin/vue-language-server'),
    '--stdio',
  },
  -- 只服务 .vue；.ts/.js 由 vtsls 独立 attach（见 lsp/vtsls.lua）
  filetypes = { 'vue' },
  root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
  init_options = {
    vue = {
      -- 关键开关：关闭 hybridMode（默认 true 需要 client 侧 tsserver 代理，nvim 无），
      -- 改用内置 TS 独立模式，是本配置能工作的根本
      hybridMode = false,
    },
    typescript = {
      -- isolated 模式必须给 tsdk：指向 vue-ls2 自带的 typescript 5.9.3
      -- （若项目中装了 TS，可改为项目 node_modules/typescript/lib 以匹配项目版本）
      tsdk = vim.fn.expand('~/.local/share/vue-ls2/node_modules/typescript/lib'),
    },
  },
}