# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Neovim configuration based on kickstart.nvim, a minimal, well-documented starting point for Neovim configuration. The setup uses lazy.nvim as the plugin manager and includes custom plugins and local plugin development.

## Key Development Commands

### Plugin Management
- `:Lazy` - View plugin status, install, update, or remove plugins
- `:Lazy update` - Update all plugins
- `:checkhealth` - Check Neovim health and plugin status

### LSP and Development Tools
- `:Mason` - Manage LSP servers, formatters, and linters
- `:ConformInfo` - View formatter configuration and status
- `:TSUpdate` - Update Tree-sitter parsers

### Code Formatting
- `stylua .` - Format all Lua files (uses .stylua.toml config)
- `stylua --check .` - Check Lua formatting without making changes
- `<leader>f` - Format current buffer using conform.nvim

### Lemur Plugin Commands
- `:LemurToggleDebug` - Toggle lemur debug mode with detailed movement logging
- `:LemurLogs` - Show lemur debug logs
- `:LemurClearLogs` - Clear lemur debug logs
- `:LemurToggleHighlight` - Toggle highlighting of reachable nodes
- `:LemurClearHighlight` - Clear current highlights
- `:LemurShowReachable` - Show nodes reachable by last used function

## Architecture

### Core Structure
- `init.lua` - Main configuration file containing all plugin setup and basic vim options
- `lua/custom/plugins/` - Custom plugin configurations and local overrides
  - `init.lua` - Main custom plugin loader and keymaps
  - `blink.lua` - Blink completion configuration
  - `ts-actions.lua` - TypeScript-specific actions
  - `commasemi.lua` - Comma/semicolon utilities
- `pack/plugins/start/` - Local plugin development (github-url, lemur)
- `lazy-lock.json` - Plugin version lockfile

### Plugin Architecture
The configuration follows a modular approach:
- Base kickstart.nvim provides LSP, telescope, treesitter, formatting
- Custom plugins extend functionality (TypeScript tools, Copilot, visual-multi)
- Local plugins for specialized workflows (GitHub URL generation, semantic code navigation)

### Key Plugins and Their Purposes
- **lazy.nvim** - Plugin manager
- **telescope.nvim** - Fuzzy finder with vertical layout and filename_first display
- **nvim-lspconfig + mason.nvim** - LSP management with auto-install
- **conform.nvim** - Code formatting with format-on-save
- **blink.cmp** - Completion engine
- **kanagawa.nvim** - Colorscheme
- **lemur** - Advanced tree-sitter based semantic code navigation (local plugin)
- **github-url** - Generate GitHub URLs for current file/line (local plugin)
- **typescript-tools.nvim** - Enhanced TypeScript LSP with import preferences
- **copilot.lua** - GitHub Copilot integration
- **vim-visual-multi** - Multiple cursor editing

### Custom Keymaps
- `<leader><tab>` - Switch to alternate buffer
- `«` (option+\) - Accept Copilot suggestion
- `'` (option+]) - Next Copilot suggestion
- `"` (option+[) - Previous Copilot suggestion
- `<M-f>` - Break line on next space
- `<M-c>` - Capitalize last typed word
- `<M-r>` - Replace with default register contents
- `<leader>gu` - Copy GitHub URL for current position
- `<leader>jk` - Insert console.log with yanked text
- `<space>st` - Open terminal in split

### Lemur Plugin Keymaps
- `<M-j>` - Move to next node of same type (preorder)
- `<M-k>` - Move to previous node of same type (preorder)
- `<M-l>` - Move to next node (preorder)
- `<M-h>` - Move to previous node (preorder)
- `<M-S-j>/<M-S-k>` - Same type navigation with Shift modifier
- `<M-C-j>/<M-C-k>` - Different line navigation with Ctrl modifier
- `<M-C-S-j>/<M-C-S-k>` - Same type + different line navigation
- `<M-i>/<M-u>` - In-order traversal navigation
- `<M-o>/<M-p>` - Post-order traversal navigation

### Language Support
- **Lua** - Full LSP support with lua_ls, stylua formatting
- **TypeScript/JavaScript** - typescript-tools.nvim with non-relative import preferences and auto ESLint fixes
- **Tailwind CSS** - LSP support
- **GraphQL** - LSP support
- **Godot** - GDScript LSP configured on port 6005

### Local Plugin Development
Two local plugins are actively developed:

1. **github-url** (`pack/plugins/start/github-url/`)
   - Generates GitHub URLs for current file/line position
   - Accessible via `<leader>gu` keymap

2. **lemur** (`pack/plugins/start/lemur/`)
   - Advanced semantic code navigation using tree-sitter AST nodes
   - Multiple traversal algorithms: preorder, levelorder, inorder, postorder
   - Same-type node filtering and different-line constraints
   - Visual highlighting of reachable nodes with auto-clear timers
   - Comprehensive debug logging system
   - Intelligent position-aware navigation with fallback strategies

### Tree-sitter Integration
The configuration heavily leverages tree-sitter for:
- Syntax highlighting with incremental selection
- Semantic code navigation via lemur plugin
- Node-aware text objects and movements
- Language-specific parsing and AST traversal

## Configuration Philosophy

This configuration prioritizes:
- **Semantic Navigation** - Tree-sitter based code movement over traditional line/character navigation
- **Documentation** - Every plugin and option is documented inline
- **Customization** - Easy to understand and modify single-file approach
- **Performance** - Lazy loading and efficient plugin management
- **Developer Experience** - TypeScript tooling, auto-formatting, and intelligent completion

## Development Best Practices
- Always check function order after writing new functions
- Use lemur for semantic code navigation instead of traditional movement
- Enable debug mode for lemur when developing navigation features
- Test navigation on various file types (Lua, JavaScript, Python, etc.)
- Verify highlighting and auto-clear functionality