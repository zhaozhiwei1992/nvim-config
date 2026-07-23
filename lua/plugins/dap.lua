-- dap.lua —— 调试（DAP）：让 nvim 能像 IDE 一样打断点、单步、看变量
-- 支持语言：Go(delve) / Python(debugpy) / C·C++·Rust(codelldb)
-- 适配器二进制由 mason 管理（已在 config/lang.lua 的 mason_tools 里：
--   delve / debugpy / codelldb），首次 nvim 自动装好，无需手动。

local M = {}

-- mason 装的适配器根目录：~/.local/share/nvim/mason/bin
local mason_bin = vim.g.data .. '/mason/bin'

----------------------------------------------------------------------
-- 1) 键位（<leader>d 系列）。原来只有注释没绑定，现补全。
----------------------------------------------------------------------
local function set_dap_keys()
  local map = vim.keymap.set
  local dap = require('dap')
  local ui = require('dapui')

  -- 执行控制
  map('n', '<leader>dc', dap.continue, { desc = '继续/启动' }) -- 有断点继续，无则启动
  map('n', '<leader>dr', dap.run_last, { desc = '重跑上次' })
  map('n', '<leader>ds', dap.terminate, { desc = '停止' })

  -- 单步
  map('n', '<leader>di', dap.step_into, { desc = '步入' })
  map('n', '<leader>do', dap.step_out, { desc = '步出' })
  map('n', '<leader>dn', dap.step_over, { desc = '单步(步过)' })
  map('n', '<leader>db', dap.toggle_breakpoint, { desc = '切断点' })
  map('n', '<leader>dB', function()
    dap.set_breakpoint(vim.fn.input('断点条件: '))
  end, { desc = '条件断点' })

  -- UI
  map('n', '<leader>du', ui.toggle, { desc = '开关界面' })
  map('n', '<leader>de', function()
    ui.eval(vim.fn.input('表达式: '))
  end, { desc = '求值表达式' })
  map({ 'n', 'v' }, '<leader>dh', function()
    require('dap.ui.widgets').hover()
  end, { desc = '悬停变量' })
end

----------------------------------------------------------------------
-- 2) 适配器：告诉 nvim「用哪个调试器、怎么启动它」
----------------------------------------------------------------------
local function setup_adapters()
  local dap = require('dap')

  -- Go：delve（mason 的 dlv 脚本）。dap-go 会自动配，这里手动更显式可控。
  dap.adapters.go = {
    type = 'server',
    port = '${port}',
    executable = { command = mason_bin .. '/dlv', args = { 'dap', '-l', '127.0.0.1:${port}' } },
  }

  -- Python：debugpy
  dap.adapters.python = {
    type = 'executable',
    command = mason_bin .. '/debugpy-adapter',
  }

  -- C / C++ / Rust：codelldb（LLDB 系，比 gdb 的 DAP 体验好）
  dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
      command = mason_bin .. '/codelldb',
      args = { '--port', '${port}' },
      detached = false,
    },
  }
end

----------------------------------------------------------------------
-- 3) 配置（launch.json 等价）：按语言给「怎么启动调试」的预设
----------------------------------------------------------------------
local function setup_configs()
  local dap = require('dap')

  -- ── Go ─────────────────────────────────────────────
  dap.configurations.go = {
    {
      type = 'go',
      name = '调试当前文件 (go)',
      request = 'launch',
      program = '${file}',
      mode = 'debug',
    },
    {
      type = 'go',
      name = '调试当前包 (go test)',
      request = 'launch',
      mode = 'test',
      program = '${fileDirname}',
    },
  }

  -- ── Python ─────────────────────────────────────────
  dap.configurations.python = {
    {
      type = 'python',
      name = '调试当前文件 (python)',
      request = 'launch',
      program = '${file}',
      python = function()
        -- 优先用当前缓冲在用的解释器，否则回落系统 python
        local venv = vim.env.VIRTUAL_ENV
        return venv and (venv .. '/bin/python') or 'python'
      end,
      justMyCode = true, -- 只调试自己代码，不进第三方库
    },
  }

  -- ── C / C++ / Rust（codelldb） ─────────────────────
  local lldb_cfg = {
    type = 'codelldb',
    request = 'launch',
    -- 编译产物路径：默认用当前文件同名无后缀（如 main.cpp → ./main）；
    -- 若不符，用 :lua require('dap').configurations.c[1].program='/path/to/bin' 临时改
    program = function()
      return vim.fn.input('可执行文件路径: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  }
  dap.configurations.c = { vim.deepcopy(lldb_cfg) }
  dap.configurations.cpp = { vim.deepcopy(lldb_cfg) }
  dap.configurations.rust = {
    {
      type = 'codelldb',
      name = '调试 cargo run (rust)',
      request = 'launch',
      program = function()
        -- 自动找 target/debug/<项目名>
        local meta = vim.fn.system('cargo metadata --format-version 1 --no-deps 2>/dev/null')
        local ok, json = pcall(vim.fn.json_decode, meta)
        local name = (ok and json and json.packages and json.packages[1]) and json.packages[1].name or ''
        local exe = vim.fn.getcwd() .. '/target/debug/' .. name
        if name == '' or vim.fn.filereadable(exe) == 0 then
          exe = vim.fn.input('可执行文件路径 (先 cargo build): ', vim.fn.getcwd() .. '/target/debug/', 'file')
        end
        return exe
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
  }
end

----------------------------------------------------------------------
-- 4) 适配器图标 + 自动装适配器（去重：codelldb/delve 已在 lang.lua）
----------------------------------------------------------------------
return {
  -- 核心库
  { 'mfussenegger/nvim-dap', event = 'VeryLazy' },

  -- C/C++/Rust：codelldb 适配器封装（只负责生成配置，二进制由 mason 装）
  {
    'leoluz/nvim-dap-go',
    ft = 'go',
    dependencies = 'mfussenegger/nvim-dap',
    opts = { delve = { path = mason_bin .. '/dlv' } },
  },

  -- Python：debugpy 封装
  {
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = 'mfussenegger/nvim-dap',
    config = function()
      require('dap-python').setup(mason_bin .. '/debugpy-adapter')
    end,
  },

  -- 界面
  {
    'rcarriga/nvim-dap-ui',
    event = 'VeryLazy',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')

      -- 断点图标（默认是个丑字母，换成 ◉/◯ 更直观）
      vim.fn.sign_define('DapBreakpoint', { text = '◉', texthl = 'ErrorMsg' })
      vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'WarningMsg' })
      vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'MatchParen', linehl = 'CursorLine' })

      dapui.setup()

      -- 开始调试自动开界面 / 结束自动关界面
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      setup_adapters()
      setup_configs()
      set_dap_keys()
    end,
  },

  -- 调试时在代码旁内联显示变量值
  { 'theHamsta/nvim-dap-virtual-text', event = 'VeryLazy', opts = {} },

  -- 自动装适配器：只列 *适配器*；codelldb/delve/debugpy 已在 config/lang.lua，
  -- 这里确保 codelldb 存在（C/C++/Rust 必需，lang.lua 已含，此处兜底不重复装）
  {
    'jay-babu/mason-nvim-dap.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    event = 'VeryLazy',
    opts = {
      ensure_installed = { 'codelldb' },
      automatic_installation = false, -- 关掉自动绑定，用我们手写的 adapter，可控
    },
  },
}
