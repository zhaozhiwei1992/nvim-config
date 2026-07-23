-- lua/plugins/which-key.lua
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- 这里可以调整窗口样式，解决折叠问题
    window = {
      layout = {
        width = { min = 20, max = 60 },
        height = { min = 4, max = 25 }, -- 稍微调大一点高度
        spacing = 3,
      },
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- 关键在这里：手动注册分组
    -- 这告诉 which-key：所有 <leader>f 开头的键都属于 "File" 组
    wk.add({
      { "<leader>b", group = "Buffer" },
      { "<leader>c", group = "Code/LSP" },
      { "<leader>f", group = "File" },   -- 对应你的 fzf-lua 和文件操作
      { "<leader>g", group = "Git" },
      { "<leader>q", group = "Quit" },
      { "<leader>w", group = "Window" },
      { "<leader>/", group = "Search" }, -- 把 / 也归入 Search
      { "<leader><tab>", group = "Buffer" }, -- 归入 Buffer
    })
  end,
}
