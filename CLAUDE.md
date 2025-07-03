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

### Custom Plugin Commands
- `:ScopeInfo` - Show node information at cursor (scope-navigation plugin)
- `:ScopeNodeTypes` - List all node types in current buffer
- `:ScopeLogs` - View scope navigation debug logs

## Architecture

### Core Structure
- `init.lua` - Main configuration file containing all plugin setup and basic vim options
- `lua/custom/plugins/` - Custom plugin configurations and local overrides
- `pack/plugins/start/` - Local plugin development (github-url, scope-navigation)
- `lazy-lock.json` - Plugin version lockfile

### Plugin Architecture
The configuration follows a modular approach:
- Base kickstart.nvim provides LSP, telescope, treesitter, formatting
- Custom plugins extend functionality (TypeScript tools, Copilot, visual-multi)
- Local plugins for specialized workflows (GitHub URL generation, scope navigation)

### Key Plugins and Their Purposes
- **lazy.nvim** - Plugin manager
- **telescope.nvim** - Fuzzy finder with vertical layout preference
- **nvim-lspconfig + mason.nvim** - LSP management with auto-install
- **conform.nvim** - Code formatting with format-on-save
- **blink.cmp** - Completion engine
- **kanagawa.nvim** - Colorscheme
- **scope-navigation** - Custom tree-sitter node navigation (local plugin)
- **github-url** - Generate GitHub URLs for current file/line (local plugin)

### Custom Keymaps
- `<leader><tab>` - Switch to alternate buffer
- `«` (option+\) - Accept Copilot suggestion
- `'` (option+]) - Next Copilot suggestion
- `"` (option+[) - Previous Copilot suggestion
- `ƒ` (option+f) - Break line on next space
- `<leader>gu` - Copy GitHub URL for current position

### Language Support
- **Lua** - Full LSP support with lua_ls, stylua formatting
- **TypeScript/JavaScript** - typescript-tools.nvim with import preferences
- **ESLint** - Auto-fix on save
- **Tailwind CSS** - LSP support
- **GraphQL** - LSP support
- **Godot** - GDScript LSP configured on port 6005

### Local Plugin Development
Two local plugins are under development:
1. **github-url** - Generates GitHub URLs for current file/line position
2. **scope-navigation** - Tree-sitter based code navigation (currently commented out but available)

The scope-navigation plugin provides semantic code navigation using tree-sitter nodes with custom keymaps and debugging capabilities.

## Configuration Philosophy

This configuration prioritizes:
- **Minimalism** - Based on single-file kickstart.nvim approach
- **Documentation** - Every plugin and option is documented inline
- **Customization** - Easy to understand and modify
- **Performance** - Lazy loading and efficient plugin management
- **Tree-sitter Integration** - Heavy use of tree-sitter for syntax awareness