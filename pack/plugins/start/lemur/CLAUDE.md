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
    same_type_picker = '<leader>ls',  -- Override default keymap (deprecated)
  },
  highlight = {
    highlight_group = 'LemurTargets', -- Customize highlight group
  },
  debug = false,  -- Enable debug mode on startup
  
  -- NEW: Extensible picker system
  pickers = {
    -- SymbolKind pickers (string shorthand)
    functions = 'Function',
    variables = 'Variable',
    classes = 'Class',
    
    -- SymbolKind picker with custom configuration
    methods = { 
      kind = 'Method', 
      keymap = '<leader>lm',
      name = 'Class Methods'
    },
    
    -- Custom function picker
    todos = {
      func = function()
        -- Your custom node collection logic
        return collect_todo_comment_nodes()
      end,
      keymap = '<leader>lt',
      name = 'TODO Comments'
    },
    
    -- Override built-in pickers
    same_type = { keymap = '<leader>ls' },
    
    -- Disable unwanted pickers
    unwanted = false,
  }
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

**Built-in Pickers:**
- **same_type**: Finds all nodes with the same type as the node under cursor

**SymbolKind Pickers (via LSP):**
- **Function**, **Variable**, **Class**, **Method**, **Property**, **Field**
- **Constructor**, **Enum**, **Interface**, **Constant**, **String**, **Number**
- **Boolean**, **Array**, **Object**, **Key**, **Null**, **EnumMember**
- **Struct**, **Event**, **Operator**, **TypeParameter**

## Extensible Picker System

### Picker Configuration Types

#### 1. SymbolKind Shorthand
```lua
pickers = {
  functions = 'Function',  -- Simple string shorthand
  variables = 'Variable',  -- Maps to vim.lsp.protocol.SymbolKind.Variable
}
```

#### 2. SymbolKind with Configuration
```lua
pickers = {
  methods = {
    kind = 'Method',
    keymap = '<leader>lm',
    name = 'Class Methods'
  }
}
```

#### 3. Custom Function Picker
```lua
pickers = {
  custom_picker = {
    func = function()
      -- Return array of tree-sitter nodes
      return your_node_collection_logic()
    end,
    keymap = '<leader>lx',
    name = 'Custom Nodes'
  }
}
```

### Runtime API

#### Register Pickers Programmatically
```lua
local lemur = require('lemur')

-- Register a new SymbolKind picker
lemur.register_picker('constants', {
  kind = 'Constant',
  keymap = '<leader>lc',
  name = 'Constants'
})

-- Register a custom function picker
lemur.register_picker('errors', {
  func = function()
    -- Collect error-related nodes
    return collect_error_nodes()
  end,
  keymap = '<leader>le'
})
```

#### Use Pickers Programmatically
```lua
-- Get and execute a picker
local picker_func = lemur.get_picker('functions')
if picker_func then
  picker_func() -- Activates sticky mode
end

-- Check if picker exists
if lemur.picker_registry['my_picker'] then
  -- Picker is registered
end
```

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