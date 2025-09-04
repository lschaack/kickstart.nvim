# CLAUDE.md - Lemur Plugin

This file provides guidance to Claude Code when working with the Lemur plugin codebase.

## Overview

Lemur is a Neovim plugin that provides semantic code navigation using tree-sitter AST nodes. It allows users to move through code structurally rather than just by lines/characters.

## Architecture

### Core Files

- `init.lua` - Plugin entry point, exports the main module
- `lua/lemur.lua` - Main implementation with all navigation logic
- `plugin/lemur.lua` - Auto-setup file that initializes the plugin with defaults

### Key Components

**Navigation Engine:**

- Uses tree-sitter to parse code into AST nodes
- Maintains cursor position state via `M.last_node`
- Implements intelligent fallback strategies when navigation fails

**Movement Functions:**

- `move_down()` - Next sibling or parent with fallback
- `move_up()` - Previous sibling or parent with fallback  
- `move_right()` - Dive into child nodes or find next sibling up tree
- `move_left()` - Move to parent node with meaningful positioning

**Debug System:**

- Optional debug logging with timestamps
- Circular buffer (max 100 entries)
- Real-time action logging and history viewing

## Configuration

### Default Keymaps

```lua
{
  move_down = '<M-j>',    -- Alt+j
  move_up = '<M-k>',      -- Alt+k  
  move_right = '<M-l>',   -- Alt+l
  move_left = '<M-h>',    -- Alt+h
}
```

### Setup Options

```lua
require('lemur').setup({
  keymaps = { ... },  -- Override default keymaps
  debug = false       -- Enable debug mode on startup
})
```

## Navigation Logic

### Node Selection Strategy

1. Get tree-sitter node at cursor position
2. If multiple nodes at same position, prefer `M.last_node` for continuity
3. Validate node boundaries contain cursor

## Development Guidelines

### Code Style

- Use descriptive function names with clear purposes
- Maintain the modular structure with helper functions
- Keep debug logging optional and performance-conscious
- Follow Lua/Neovim plugin conventions

### Testing Navigation

- Use `:LemurToggleDebug` to enable detailed movement logging
- Test on various file types (Lua, JavaScript, Python, etc.)
- Verify fallback behavior at file boundaries
- Check multi-line node handling

### Key Algorithms

- **Sibling traversal**: Iterate parent children to find adjacent named nodes
- **Tree climbing**: Recursively search up tree for next sibling
- **Position validation**: Ensure movements result in different cursor positions
- **State persistence**: Track last node to maintain navigation context

## Common Use Cases

1. **Function navigation** - Move between function definitions
2. **Block traversal** - Navigate if/else, loops, try/catch blocks  
3. **Expression trees** - Move through nested expressions
4. **Scope jumping** - Quick parent scope navigation

## Future Enhancement Areas

- Custom node type filtering
- Language-specific navigation rules
- Visual feedback for current node
- Integration with other tree-sitter tools
- Performance optimization for large files

