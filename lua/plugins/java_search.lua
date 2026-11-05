-- java_search.lua —— 本地插件 spec（逻辑在 lua/local/java-search/，命令/键位在其 plugin/ 下）
-- 2026-11-06：替代 jdtls 的搜索式 Java 导航，设计见 PLAN-java-search.md
return {
  {
    dir = vim.fn.stdpath('config') .. '/lua/local/java-search',
    name = 'java-search',
    lazy = false,
  },
}
