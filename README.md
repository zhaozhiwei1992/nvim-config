# Neovim 配置

从 Vim 老用户迁移到现代 Neovim 的 Lua 配置。纯 Lua 手写，基于 lazy.nvim 按需加载，启动 **<60ms**。覆盖 LSP / Treesitter / 补全 / 调试 / Git / 模糊检索全链路，支持 Go / Rust / Python / TS·JS / Java / C·C++ / Lua 七大语言。

> **工具分工**：nvim 做日常编程主力，emacs (spacemacs) 专职 orgmode(GTD/agenda) 与 magit。org/magit 不进本配置。

## 性能实测

| 场景             | vim(裸) | nvim(--clean) | nvim(当前配置) |
|------------------|---------|---------------|----------------|
| 启动时间(3次均值) | ~2020ms | ~26ms         | **~51ms**      |
| 打开 77MB 大日志  | ~2.20s  | ~0.14s        | —              |

lazy.nvim 按需加载，全套 34 个插件加身后启动仍 <60ms。

## 特性

- **LSP** — nvim 0.12 原生 `vim.lsp.config` / `vim.lsp.enable` API，无需 nvim-lspconfig 的 `setup()`
- **补全** — blink.cmp（2026 年最佳实践，性能碾压 nvim-cmp）
- **Treesitter** — main 分支原生 API，`vim.treesitter.start()` + 异步安装缺失 parser
- **调试 (DAP)** — 断点 / 单步 / 变量查看，支持 Go(delve) / Python(debugpy) / C·C++·Rust(codelldb)
- **模糊检索** — fzf-lua，复用本机 fzf / rg / fd
- **文件导航** — neo-tree 文件树 + oil 目录式编辑 + aerial 符号大纲
- **格式化** — conform.nvim 保存时统一格式化，LSP fallback
- **Git** — gitsigns 行内标记 + lazygit 外挂 TUI（magit/forge 留 emacs）
- **opencode 上下文桥** — 本地插件，一键把 nvim 文件路径 / 行号 / 选区发送到 tmux 中的 AI 助手

## 目录结构

```
~/.config/nvim/
├── init.lua                   # 唯一入口：设 leader、加载各模块
├── lazy-lock.json             # 插件版本锁定
├── lsp/                       # 各语言 LSP server 配置（0.12 原生格式）
│   ├── gopls.lua
│   ├── rust_analyzer.lua
│   ├── basedpyright.lua
│   ├── ruff.lua
│   ├── vtsls.lua
│   ├── jdtls.lua
│   ├── lua_ls.lua
│   └── clangd.lua
    └── lua/
        ├── config/                # 基础配置模块
        │   ├── options.lua        #   选项（行号/缩进/搜索/折叠...）
        │   ├── keymaps.lua        #   通用键位（插件无关）
        │   ├── autocmds.lua       #   自动命令（yank 高亮/去尾空/bigfile 策略）
        │   ├── lazy.lua           #   lazy.nvim 引导 + 插件 spec 汇总
        │   └── lang.lua           #   各语言 LSP/格式化/DAP 清单
        ├── local/                 # 自研本地插件（标准结构，随时可抽出独立 repo）
        │   ├── logjump/           #   日志堆栈跳转
        │   │   ├── lua/logjump/
        │   │   │   └── init.lua   #     模块逻辑
        │   │   └── plugin/
        │   │       └── init.lua   #     命令 + 键位注册
        │   └── opencode-ctx/      #   opencode 上下文桥
        │       ├── lua/opencode_ctx/
        │       │   └── init.lua   #     模块逻辑
        │       └── plugin/
        │           └── init.lua   #     命令 + 键位注册
        └── plugins/               # 每个插件一个 spec 文件（第三方 + 本地插件 spec）
            ├── editor.lua         #   which-key / Comment / surround / mini.align
            ├── theme.lua          #   tokyonight + lualine + bufferline
            ├── treesitter.lua     #   语法高亮/折叠/缩进
            ├── lsp.lua            #   LSP 配置 + 诊断 + mason 自动安装
            ├── cmp.lua            #   blink.cmp 补全
            ├── fzf.lua            #   fzf-lua 模糊检索
            ├── files.lua          #   neo-tree / oil / aerial
            ├── git.lua            #   gitsigns / lazygit
            ├── dap.lua            #   DAP 调试
            ├── formatter.lua      #   conform.nvim 统一格式化
            ├── logjump.lua        #   logjump spec（dir → lua/local/logjump）
            └── opencode_ctx.lua   #   opencode-ctx spec（dir → lua/local/opencode-ctx）
```

### 加载流程

```
nvim 启动 → init.lua
  ├─ vim.g.mapleader = ' '          ← 必须最先设
  ├─ require('config.options')      ← 纯选项
  ├─ require('config.keymaps')      ← 通用键位
  ├─ require('config.autocmds')     ← 注册 autocmd
  └─ require('config.lazy')         ← lazy.nvim 引导
       └─ 扫描 lua/plugins/*.lua，按 event/cmd/keys/ft 按需加载
```

## 环境要求

| 依赖             | 最低版本   | 说明                                       |
|------------------|-----------|--------------------------------------------|
| **neovim**       | 0.11+     | 使用原生 `vim.lsp.config` / `vim.lsp.enable` |
| **node**         | 18+       | TS/JS LSP (vtsls/eslint/prettier) 运行时    |
| **git**          | 2.x       | lazy.nvim bootstrap                         |
| **ripgrep (rg)** | —         | fzf-lua 全局检索                            |
| **fd**           | —         | fzf-lua 文件查找                            |
| **fzf**          | —         | fzf-lua 模糊匹配                            |
| **tree-sitter-cli** | 0.26+   | main 分支编译 parser 必需                    |
| **tmux**         | 3.x       | opencode 上下文桥 / 三窗布局（可选）          |
| **xclip** / **wl-clipboard** | —   | 系统剪贴板互通                |

> Arch Linux 一键安装：`sudo pacman -S neovim nodejs npm git ripgrep fd fzf tree-sitter-cli tmux xclip`

## 快速安装

### 1. 克隆配置

```sh
git clone <your-repo-url> ~/.config/nvim
```

### 2. 首次启动

```sh
nvim
```

首次启动会自动完成以下操作（无需手动）：

| 机制                   | 负责内容                                  | 触发时机                |
|------------------------|------------------------------------------|------------------------|
| lazy.nvim bootstrap    | 自动克隆自身 + 安装 34 个插件              | 首次 nvim              |
| mason-tool-installer   | 读 `config/lang.lua` 安装 LSP/格式化/DAP  | `VeryLazy` 事件        |
| treesitter `defer_fn`  | 遍历 parser 列表，缺则 `ts.install()`      | 插件 config 阶段        |

### 3. 验证

```sh
nvim --clean       # 确认裸启动正常
nvim               # 打开 nvim 后执行 :checkhealth
```

`:checkhealth` 确认 `lazy` / `mason` / `vim.lsp` 全绿即就绪。

### 4. 各语言特殊安装

```sh
# Rust：用 rustup 组件更稳（conform 的 rustfmt 由 rustc 自带）
rustup component add rust-analyzer

# Java：mason 从 eclipse 源下载国内常超时，用系统包绕开
paru -S jdtls

# lazygit（可选，<leader>gg 调用）
paru -S lazygit
```

## 插件清单

| 分类       | 插件                        | 替代的老插件          | 说明                          |
|------------|----------------------------|-----------------------|-------------------------------|
| 编辑增强   | which-key.nvim             | —                     | 键位提示弹窗                   |
|            | Comment.nvim               | NERD_commenter        | `gcc` / `gc{motion}` 注释切换 |
|            | nvim-surround              | vim-surround          | `cs"'` / `ds"` / `ysiw"`      |
|            | mini.align                 | vim-easy-align        | `gaip=` 对齐                   |
|            | vim-repeat                 | —                     | `.` 重复增强                   |
|            | persistence.nvim           | —                     | 会话恢复                       |
|            | vim-visual-multi           | —                     | `<C-n>` 多光标编辑             |
| 配色 UI    | tokyonight.nvim            | molokai               | 配色主题                       |
|            | lualine.nvim               | vim-airline           | 状态栏                         |
|            | bufferline.nvim            | bufexplorer           | Buffer 标签栏                  |
| 语法       | nvim-treesitter (main)     | —                     | 基于语法的语法高亮/折叠/缩进    |
| LSP        | nvim-lspconfig             | syntastic             | LSP 配置（0.12 原生 API）      |
|            | mason.nvim                 | —                     | LSP/格式化/DAP 二进制管理       |
|            | mason-tool-installer       | —                     | 自动安装各语言工具              |
|            | fidget.nvim                | —                     | LSP 进度美化                   |
| 补全       | blink.cmp                  | YouCompleteMe / coc   | 2026 最佳实践补全引擎           |
| 模糊检索   | fzf-lua                    | ctrlp / LeaderF       | 文件/内容/符号检索              |
| 文件导航   | neo-tree.nvim              | NERDTree              | 文件树                         |
|            | oil.nvim                   | —                     | 目录式编辑                     |
|            | aerial.nvim                | Tagbar                | 符号大纲（基于 LSP/TS）         |
| Git        | gitsigns.nvim              | vim-gitgutter         | 行内 git 标记 / hunk 操作       |
|            | lazygit.nvim               | vim-fugitive          | lazygit 外挂 TUI               |
| 调试       | nvim-dap                   | —                     | DAP 调试核心                    |
|            | nvim-dap-ui                | —                     | 调试界面（变量/调用栈/断点）     |
|            | nvim-dap-virtual-text      | —                     | 内联显示变量值                  |
|            | nvim-dap-go                | —                     | Go delve 适配器                 |
|            | nvim-dap-python            | —                     | Python debugpy 适配器           |
|            | mason-nvim-dap             | —                     | DAP 适配器自动安装              |
| 格式化     | conform.nvim               | —                     | 保存时统一格式化                |
| 本地插件   | opencode_ctx.lua           | —                     | nvim → tmux AI 助手上下文桥      |

## 键位速查

### 通用

| 键位            | 模式  | 作用                          |
|-----------------|-------|-------------------------------|
| `<leader>nh`    | n     | 取消高亮搜索结果               |
| `<C-h/j/k/l>`   | n     | 窗口切换（配合 tmux 无缝跳转）  |
| `J` / `K`       | v     | 下移 / 上移选中行              |
| `<leader>p`     | x     | 粘贴不覆盖寄存器               |
| `<leader>d`     | n/v   | 删除不入寄存器                  |
| `<leader>Y`     | n     | 复制全文到剪贴板               |
| `<` / `>`       | v     | 缩进并保持选区                 |
| `<leader>ev`    | n     | 编辑 init.lua                  |
| `<leader>sv`    | n     | 重载配置                       |
| `<leader>qq`    | n     | 全部退出                       |

### 模糊检索 (fzf-lua)

| 键位       | 作用              |
|------------|-------------------|
| `<leader>ff` | 找文件            |
| `<leader>fg` | 全局内容搜索      |
| `<leader>fb` | 切缓冲区          |
| `<leader>fh` | 帮助              |
| `<leader>fr` | 最近文件          |
| `<leader>fs` | 工作区符号        |
| `<leader>fd` | 文档诊断          |

### LSP

| 键位         | 作用       |
|--------------|------------|
| `gd`         | 跳转定义   |
| `gr`         | 引用       |
| `gD`         | 声明       |
| `gi`         | 实现       |
| `K`          | 悬停文档   |
| `<leader>ca` | 代码操作   |
| `<leader>cr` | 重命名     |
| `<leader>cd` | 行诊断     |
| `<leader>cf` | 格式化     |
| `[d` / `]d`  | 上/下一条诊断 |

### 文件导航

| 键位   | 作用           |
|--------|----------------|
| `<F5>` | 文件树 (neo-tree) |
| `<F6>` | 符号大纲 (aerial) |
| `-`    | 浏览目录 (oil)  |

### Git

| 键位        | 作用            |
|-------------|-----------------|
| `<leader>gg` | 打开 lazygit    |

### 调试 (DAP)

| 键位         | 作用              |
|--------------|-------------------|
| `<leader>db` | 切换断点          |
| `<leader>dB` | 条件断点          |
| `<leader>dc` | 继续/启动调试     |
| `<leader>dn` | 单步(步过)        |
| `<leader>di` | 步入              |
| `<leader>do` | 步出              |
| `<leader>ds` | 停止调试          |
| `<leader>dr` | 重跑上次          |
| `<leader>du` | 开/关调试界面     |
| `<leader>dh` | 悬停变量          |
| `<leader>de` | 求值表达式        |

### opencode 上下文桥（仅在 tmux 会话内）

| 键位        | 模式 | 作用                                    |
|-------------|------|-----------------------------------------|
| `<leader>ol` | n   | 发送 `文件路径:行号` 到 AI 助手          |
| `<leader>of` | n   | 发送 `@文件路径`（让 AI 读取整个文件）   |
| `<leader>os` | v   | 发送选中文本 + 来源标签                  |

命令：`:OpencodeLoad [session]` — 通过 tmuxp 加载开发环境会话。

## 支持的语言

| 语言       | LSP            | 格式化               | 调试       |
|------------|----------------|----------------------|------------|
| Go         | gopls          | goimports + gofumpt  | delve      |
| Rust       | rust_analyzer  | rustfmt              | codelldb   |
| Python     | basedpyright   | ruff                 | debugpy    |
| TS / JS    | vtsls          | prettier             | —          |
| Java       | jdtls          | google-java-format   | —          |
| C / C++    | clangd         | —                    | codelldb   |
| Lua        | lua_ls         | stylua               | —          |

## tmux 三窗布局

配合 tmuxp 实现左 nvim / 右上 AI / 右下 console 的开发布局：

```
┌──────────────────────┬──────────────────┐
│                      │   AI 助手 (右上)   │
│                      ├──────────────────┤
│   nvim (左，大)       │                  │
│                      │   console (右下)  │
└──────────────────────┴──────────────────┘
```

```sh
tmuxp load dev    # 启动三窗布局（需 ~/.config/tmuxp/dev.yaml）
```

``` yaml
session_name: dev
start_directory: "#{pane_current_path}"
shell_command_before:
  - ''  # 占位，确保各 pane 独立命令
windows:
  - window_name: code
    layout: main-vertical
    options:
      main-pane-width: 70%    # 左 nvim 占 55列 宽,可以通过stty size命令来看行列,可以直接设置百分比
    panes:
      - shell_command:
          - nvim              # pane 0：左 nvim
      - shell_command:
          - nvm use system
          - opencode            # pane 1：右上 opencode
      - shell_command: []     # pane 2：右下 console(空 shell)

```

## 维护命令

| 操作               | 命令                                                |
|--------------------|-----------------------------------------------------|
| 更新所有插件        | `:Lazy sync`                                        |
| 检查可用更新        | `:Lazy check`                                       |
| 查看更新历史        | `:Lazy log`                                         |
| 安装/更新 LSP 工具  | `:Mason`                                            |
| 安装缺失 parser     | 重启自动补装；或 `:lua require('nvim-treesitter').install{'go'}` |
| 编辑配置即时生效    | `<leader>sv`                                        |
| 检查系统健康        | `:checkhealth`                                      |
| 回退某个插件        | `:Lazy` 界面中光标移到插件按 `X`                     |

> nvim-treesitter main 分支已废弃 `:TSUpdate` / `:TSInstall` 命令。

## 常见问题

<details>
<summary><b>Invalid plugin spec（含 mason_tools/servers 字段）</b></summary>

数据表不能放 `lua/plugins/` 下——lazy.nvim 会把该目录所有文件的 `return` 当插件 spec。语言清单放 `lua/config/lang.lua`，`lsp.lua` 用 `require('config.lang')` 引用。
</details>

<details>
<summary><b>colorscheme 不生效 / 主题 spec 报语法错</b></summary>

`vim.cmd.colorscheme(...)` 不能写在 `return {...}` 之后（Lua 中 return 后不执行）。放进 spec 的 `config = function(_, opts) ... end` 里。
</details>

<details>
<summary><b>Treesitter 报 <code>module 'nvim-treesitter.configs' not found</code></b></summary>

nvim-treesitter main 分支已废弃 `configs` 模块与 `ensure_installed` 旧选项，改用原生 `vim.treesitter.start()` + `ts.install()`。本配置已是新写法。
</details>

<details>
<summary><b>Treesitter 编译报 <code>ENOENT: 'tree-sitter'</code></b></summary>

main 分支编译 parser 需外部 `tree-sitter` CLI：`sudo pacman -S tree-sitter-cli`。
</details>

<details>
<summary><b>jdtls(Java) 装不上</b></summary>

mason 从 eclipse 官方源下载，国内常 404/超时。用系统包绕开：`paru -S jdtls`。
</details>

<details>
<summary><b>lua_ls 不 attach（写配置无补全/诊断）</b></summary>

mason_tools 清单漏了 `lua-language-server`，在 `config/lang.lua` 的 `mason_tools` 中补上。
</details>

<details>
<summary><b>剪贴板 <code>+寄存器失效</code></b></summary>

装 `xclip` (X11) 或 `wl-clipboard` (Wayland)。
</details>

<details>
<summary><b>Treesitter 报 <code>'buf' cannot be passed for window-local option 'foldmethod'</code></b></summary>

`foldmethod` / `foldexpr` / `foldlevel` 是 **window-local**，要用 `vim.wo` 而非 `vim.bo`。
</details>

## 换机迁移

```sh
# 新机器一键还原
sudo pacman -S neovim nodejs npm git ripgrep fd fzf tree-sitter-cli tmux xclip
git clone <your-repo-url> ~/.config/nvim
nvim    # lazy 自动 bootstrap + 装插件 + mason 装 LSP + treesitter 装 parser
```

## 设计决策

- **纯 Lua，不保留 vimrc**：两套配置体系(Vimscript + Lua)互相打架，彻底搬到 Lua。
- **syntastic 已淘汰**：由 LSP `vim.diagnostic` 全面替代，同步语法检查会拖慢启动。
- **magit / orgmode 留 emacs**：nvim 的 Neogit(~90% magit) 和 nvim-orgmode 无法完全覆盖深度用法（Forge / org-babel / plantuml 作图）。
- **大文件策略**：`vim.b.bigfile` 在 >1MB 文件上自动禁用 syntax/treesitter/undo，纯文本浏览。
- **blink.cmp 替代 nvim-cmp**：2026 年性能与零配置最优方案。
- **fzf-lua 替代 Telescope**：本机 fzf/rg/fd 齐全，fzf-lua 是最快方案。
- **自研插件用标准目录结构**：放在 `lua/local/<name>/` 下，lazy.nvim spec 中 `dir` 指向独立插件目录，而非整个 config。

## License

个人配置，随意使用。
