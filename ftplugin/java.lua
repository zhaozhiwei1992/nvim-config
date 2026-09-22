-- ftplugin/java.lua —— Java 专属：nvim-jdtls 插件（start_or_attach 方案）
-- 为什么不用 vim.lsp.config('jdtls')/lspconfig：
--   nvim-jdtls 是官方 README 推荐的唯一前端（提供 jdt:// 跳转、java.action.* 命令、测试、
--   java.project.* 配置等扩展能力），lspconfig 只是降级平替。其他语言照旧 lspconfig/vim.lsp.enable。
-- ⚠️ lua/config/lang.lua 的 servers 里已移除 'jdtls'：vim.lsp.enable 与 start_or_attach 会双 client（两个 JVM）！
-- ⚠️ 插件要求 cmd 是 table（可执行 + 参数），不是 vim.lsp.rpc.start 的函数。
-- jdtls 由 mason 安装（mason 包自带 lombok.jar，PATH 注入在 init.lua）。

-- workspace：按项目隔离，落 cache（jdtls 多进程不能共用同一 -data；默认 /tmp 重启丢索引）
local root = vim.fs.root(0, { 'pom.xml', 'build.gradle', 'settings.gradle', '.git' }) or vim.fn.getcwd()
local ws = vim.fn.stdpath('cache') .. '/jdtls-workspace/' .. vim.fn.fnamemodify(root, ':t')

local config = {
  cmd = { 'jdtls', '-data', ws },
  root_dir = root,
  settings = {
    java = {
      -- 按需：格式化风格 / 组织导入阈值等（eclipse.jdt.ls 同名 setting）
      -- organizeImports = { starThreshold = 99 },
      -- 索引范围裁剪（2026-09 加，省内存/加快索引）：不索引构建产物与缓存
      -- 显式列出（含 target/**），避免 jdtls 把生成字节码也建索引
      import = {
        exclusions = {
          '**/node_modules/**',
          '**/.metadata/**',
          '**/archetype-resources/**',
          '**/META-INF/maven/**',
          '**/target/**',
          '**/build/**',
          '**/.gradle/**',
        },
      },
    },
  },
}

-- lombok agent：mason 包自带 jar；不加则 @Getter/@Data 类满屏报错
local lombok = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason/packages/jdtls/lombok.jar')
if vim.fn.filereadable(lombok) == 1 then
  table.insert(config.cmd, '--jvm-arg=-javaagent:' .. lombok)
end

-- JVM 内存/GC 调优（2026-09 实测，详见 nvim实践.org「jdtls(Java)」节内存小节）
-- 问题：jdtls.py 启动器硬编码 -Xms1G 且不设 -Xmx → JVM 默认堆上限=物理内存 1/4（本机 32G→8G），
--       索引期 G1 数秒内 commit 3G+、之后一路涨，RSS 轻松超过 IDEA —— 这就是"比 IDEA 还吃内存"的原因。
-- 实测（demo/springboot 同项目对比）：RSS@8s 默认 453MB → 调优 322MB；堆 commit 上限 8G → 1.5G。
-- 参数来源：vscode-java PR#1262 / jdtls issue#1469、#2509 社区验证组合。
-- 生效机制：--jvm-arg 追加在启动器自带 -Xms1G 之后，HotSpot 取最后一个 -Xms/-Xmx（已验证生效）。
-- 若大单体/多模块项目 OOM，把 -Xmx1536m 调成 2048m 即可，其余参数不动。
local jvm_args = {
  '-Xms256m',                -- 覆盖启动器 -Xms1G：启动不预占 1G
  '-Xmx1536m',               -- 堆上限 1.5G（日常单模块够用；Spring 大单体改 2G）
  '-XX:+UseParallelGC',     -- 吞吐型 GC，索引/全量编译场景比 G1 省内存（vscode-java 官方建议组合）
  '-XX:GCTimeRatio=4',      -- GC 时间预算放宽，自适应扩/缩堆更积极
  '-XX:AdaptiveSizePolicyWeight=90',
  '-XX:MinHeapFreeRatio=5', -- GC 后允许堆缩回（索引高峰过后归还内存）
  '-XX:MaxHeapFreeRatio=10',
  '-Dsun.zip.disableMemoryMapping=true', -- jar/zip 不 mmap，省原生内存与地址空间
}
for _, a in ipairs(jvm_args) do
  table.insert(config.cmd, '--jvm-arg=' .. a)
end

-- 客户端能力：对 jdtls 全关 dynamicRegistration，强制静态上报全部 provider。
-- jdtls 1.60 对声明支持动态注册的 client，把 codeAction/hover/definition 等移出 initialize 静态 caps、
-- 改走 client/registerCapability；但它对 codeAction/rename/formatting 从不发起注册，nvim 0.12 也
-- 合并不进来 → 这 6 个核心 provider 永久缺失（vim.lsp.buf.xxx 全部报 not supported）。
-- 关闭该开关后 initialize 即全量静态上报（先验于 2026-08-24 原生配置，迁移至此）。
local capabilities = vim.lsp.protocol.make_client_capabilities()
for _, sub in pairs(capabilities.textDocument or {}) do
  if type(sub) == 'table' then sub.dynamicRegistration = false end
end
for _, sub in pairs(capabilities.workspace or {}) do
  if type(sub) == 'table' then sub.dynamicRegistration = false end
end
config.capabilities = capabilities
-- 注：extendedClientCapabilities（advancedExtractRefactoringSupport、inferSelectionSupport 等）
-- 由插件自带默认值在 start_or_attach 内自动合并，无需手写。

require('jdtls').start_or_attach(config)

-- ===== Java 专属键位：与全局统一为 <leader>c 命令族（buffer-local，仅 java buffer 生效） =====
-- 全局已有 <leader>ca 代码操作 / <leader>cr 重命名 / <leader>cd 行诊断；Java 追加：
--   <leader>ci organize imports   <leader>cv extract variable
--   <leader>cx extract constant     <leader>cm extract method
-- extract 系列内部走 jdtls 扩展协议 java/getRefactorEdit + java/inferSelection（推断选区），
-- 不依赖 codeAction provider；organizeImports 走 java/organizeImports 扩展请求。
local jdtls = require('jdtls')
local function jmap(mode, lhs, desc, fn)
  vim.keymap.set(mode, '<leader>' .. lhs, fn, { buffer = 0, desc = desc })
end

jmap('n', 'ci', 'Java: organize imports', jdtls.organize_imports)
jmap('n', 'cv', 'Java: extract variable', function() jdtls.extract_variable() end)
jmap('v', 'cv', 'Java: extract variable', function() jdtls.extract_variable(true) end)
jmap('n', 'cx', 'Java: extract constant', function() jdtls.extract_constant() end)
jmap('v', 'cx', 'Java: extract constant', function() jdtls.extract_constant(true) end)
jmap('n', 'cm', 'Java: extract method', function() jdtls.extract_method() end)
jmap('v', 'cm', 'Java: extract method', function() jdtls.extract_method(true) end)