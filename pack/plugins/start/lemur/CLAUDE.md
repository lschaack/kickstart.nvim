# CLAUDE.md - Lemur Plugin

This file provides guidance to Claude Code when working with the Lemur plugin codebase.

## Overview

Lemur is a Neovim plugin that provides sticky mode navigation using tree-sitter AST nodes. It allows users to create navigation layers defined by node pickers and navigate through them with simple j/k keys.

## Architecture

### Core Files

- `init.lua` - Plugin entry point, exports the main module
- `lua/lemur.lua` - Main implementation with sticky mode logic
- `plugin/lemur.lua` - Auto-setup file that initializes the plugin with defaults

### Key Components

**Sticky Mode System:**

- Users configure key combinations to toggle sticky modes
- Each sticky mode is defined by a node picker function
- When active, all picked nodes are highlighted
- Simple j/k navigation moves between nodes in the layer
- Escape key clears the sticky mode

**Node Pickers:**

- Functions that return collections of tree-sitter nodes
- Define the "layer" of nodes available for navigation
- Built-in same-type picker for nodes matching cursor node type
- Extensible system for custom pickers

**Debug System:**

- Optional debug logging with timestamps
- Circular buffer (max 100 entries)
- Real-time action logging and history viewing

## Configuration

### Default Keymaps

```lua
{
  same_type_picker = '<leader>ls',  -- Toggle same-type sticky mode
}
```

### Setup Options

```lua
require('lemur').setup({
  keymaps = { 
    same_type_picker = '<leader>ls',  -- Override default keymap
  },
  highlight = {
    highlight_group = 'LemurTargets', -- Customize highlight group
  },
  debug = false  -- Enable debug mode on startup
})
```

## Sticky Mode Usage

### Basic Workflow

1. Position cursor on a node of interest
2. Press `<leader>ls` to activate same-type sticky mode
3. All nodes of the same type are highlighted
4. Use `j` to move to next node, `k` to move to previous node
5. Press `<Esc>` to exit sticky mode

### Available Pickers

- **same_type**: Finds all nodes with the same type as the node under cursor

## Development Guidelines

### Adding Custom Pickers

```lua
local function my_custom_picker()
  local root = get_tree_root()
  local nodes = collect_specific_nodes(root) -- Your collection logic
  activate_sticky_mode(nodes, 'my_picker')
end

-- Register with keymap
vim.keymap.set('n', '<leader>lc', M.toggle_sticky_mode(my_custom_picker, 'custom'), 
  { desc = 'Toggle custom sticky mode' })
```

### Key Functions

- `activate_sticky_mode(nodes, picker_name)` - Starts sticky mode with given nodes
- `clear_sticky_mode()` - Exits sticky mode and clears highlights
- `navigate_next()` / `navigate_prev()` - Move through nodes in sticky mode
- `M.toggle_sticky_mode(picker_func, name)` - Creates toggle function for keymaps

### Code Style

- Keep picker functions focused and simple
- Use descriptive names for picker functions
- Maintain the modular structure
- Follow Lua/Neovim plugin conventions

### Testing Navigation

- Use `:LemurToggleDebug` to enable detailed logging
- Test sticky mode on various file types
- Verify highlighting behavior
- Check wrap-around navigation (end to beginning)

## Common Use Cases

1. **Same-type navigation** - Move between all function definitions, variables, etc.
2. **Custom layer navigation** - Create pickers for specific node patterns
3. **Structural editing** - Navigate related code structures quickly
4. **Code review** - Jump between similar constructs in large files

## Extension Points

- Custom picker functions for specific node types or patterns
- Language-specific navigation rules
- Integration with other tree-sitter tools
- Visual feedback customization

## Commands

- `:LemurToggleDebug` - Toggle debug logging
- `:LemurLogs` - Show debug log history
- `:LemurClearLogs` - Clear debug logs
- `:LemurClearSticky` - Manually exit sticky mode