# Lemur 🐒

> Semantic code navigation for Neovim using tree-sitter and LSP

Lemur is a Neovim plugin that provides **sticky mode navigation** for moving between semantically related code elements. Navigate through functions, variables, classes, or any custom node collection with simple `j`/`k` keys while all targets are highlighted.

## ✨ Features

- **🎯 Sticky Mode Navigation** - Activate a navigation layer, use `j`/`k` to move between nodes
- **🔍 LSP Integration** - Built-in support for all LSP SymbolKind types (Function, Variable, Class, etc.)
- **🌳 Tree-sitter Based** - Precise node detection using tree-sitter AST
- **⚡ Extensible** - Define custom pickers with your own logic
- **🎨 Visual Highlighting** - All reachable nodes highlighted during navigation
- **🔧 Configurable** - Minimal setup to full customization
- **📝 Debug Support** - Built-in logging and debug commands

## 🚀 Quick Start

### Basic Usage

1. **Position cursor** on any code element (function, variable, etc.)
2. **Activate picker** using a keymap (e.g., `<leader>lf` for functions)
3. **Navigate** with `j` (next) and `k` (previous)
4. **Exit** with `<Esc>`

### Example Workflow

```lua
-- On this function definition
function calculateTotal(items) {
  -- Press <leader>lf to activate function picker
  -- All functions in the file are now highlighted
  -- Use j/k to jump between them
  -- Press <Esc> to exit sticky mode
}
```

## 📦 Installation

### Requirements

- Neovim 0.8+
- tree-sitter parsers for your languages
- LSP server (optional, for SymbolKind pickers)

### Using lazy.nvim

```lua
{
  dir = '/path/to/lemur', -- or use a git repo
  name = 'lemur',
  opts = {
    pickers = {
      functions = { kind = 'Function', keymap = '<leader>lf' },
      variables = { kind = 'Variable', keymap = '<leader>lv' },
    }
  }
}
```

### Manual Setup

```lua
require('lemur').setup({
  pickers = {
    functions = 'Function',
    variables = 'Variable',
  }
})
```

## 🎯 Built-in Pickers

| Picker | Default Keymap | Description |
|--------|----------------|-------------|
| `same_type` | `<leader>ls` | Navigate nodes of same type as cursor |

## 🔧 Configuration

### Minimal Configuration

```lua
require('lemur').setup({
  pickers = {
    functions = 'Function',  -- SymbolKind shorthand
    variables = 'Variable',
  }
})
```

### Full Configuration

```lua
require('lemur').setup({
  debug = false,  -- Enable debug logging
  
  highlight = {
    highlight_group = 'LemurTargets',  -- Highlight group for nodes
  },
  
  pickers = {
    -- SymbolKind pickers (string shorthand)
    functions = 'Function',
    variables = 'Variable',
    classes = 'Class',
    methods = 'Method',
    
    -- SymbolKind with custom configuration
    constructors = {
      kind = 'Constructor',
      keymap = '<leader>lc',
      name = 'Constructors'
    },
    
    -- Custom function picker
    todos = {
      func = function()
        local nodes = {}
        local parser = vim.treesitter.get_parser(0)
        if not parser then return nodes end
        
        local tree = parser:parse()[1]
        if not tree then return nodes end
        
        local function traverse(node)
          if node:type() == 'comment' then
            local text = vim.treesitter.get_node_text(node, 0)
            if text and (text:match('TODO') or text:match('FIXME')) then
              table.insert(nodes, node)
            end
          end
          for child in node:iter_children() do
            traverse(child)
          end
        end
        
        traverse(tree:root())
        return nodes
      end,
      keymap = '<leader>lt',
      name = 'TODO Comments'
    },
    
    -- Override built-in pickers
    same_type = { keymap = '<leader>ls', name = 'Same Type Nodes' },
    
    -- Disable unwanted pickers
    unwanted_picker = false,
  }
})
```

## 📚 API Reference

### Setup Options

#### `debug` (boolean)
Enable debug logging with detailed action information.
```lua
debug = true  -- Shows detailed logs for troubleshooting
```

#### `highlight` (table)
Configure visual highlighting options.
```lua
highlight = {
  highlight_group = 'LemurTargets'  -- Vim highlight group name
}
```

#### `pickers` (table)
Define navigation pickers. See [Picker Configuration](#picker-configuration).

### Picker Configuration

#### SymbolKind Shorthand
```lua
pickers = {
  functions = 'Function',  -- Maps to vim.lsp.protocol.SymbolKind.Function
  variables = 'Variable',
}
```

#### SymbolKind with Options
```lua
pickers = {
  methods = {
    kind = 'Method',              -- LSP SymbolKind
    keymap = '<leader>lm',        -- Key binding
    name = 'Class Methods'        -- Display name
  }
}
```

#### Custom Function Picker
```lua
pickers = {
  custom_picker = {
    func = function()
      -- Must return array of tree-sitter nodes
      return collect_your_nodes()
    end,
    keymap = '<leader>lx',
    name = 'Custom Nodes'
  }
}
```

### Available SymbolKind Values

- `File`, `Module`, `Namespace`, `Package`
- `Class`, `Method`, `Property`, `Field`, `Constructor`
- `Enum`, `Interface`, `Function`, `Variable`, `Constant`
- `String`, `Number`, `Boolean`, `Array`, `Object`
- `Key`, `Null`, `EnumMember`, `Struct`, `Event`
- `Operator`, `TypeParameter`

### Runtime API

#### Register Pickers Programmatically

```lua
local lemur = require('lemur')

-- Register SymbolKind picker
lemur.register_picker('constants', {
  kind = 'Constant',
  keymap = '<leader>lc',
  name = 'Constants'
})

-- Register custom function picker
lemur.register_picker('imports', {
  func = function()
    return collect_import_statements()
  end,
  keymap = '<leader>li'
})
```

#### Get and Execute Pickers

```lua
-- Get picker function
local picker_func = lemur.get_picker('functions')
if picker_func then
  picker_func()  -- Activate sticky mode
end

-- Check if picker exists
if lemur.picker_registry['my_picker'] then
  -- Picker is available
end
```

### Commands

- `:LemurToggleDebug` - Toggle debug logging
- `:LemurLogs` - Show debug log history  
- `:LemurClearLogs` - Clear debug logs
- `:LemurClearSticky` - Manually exit sticky mode

## 🎮 Default Keymaps

During sticky mode:
- `j` - Move to next node
- `k` - Move to previous node
- `<Esc>` - Exit sticky mode

## 🧩 Examples

### Language-Specific Navigation

```lua
-- TypeScript/JavaScript setup
pickers = {
  functions = { kind = 'Function', keymap = '<leader>lf' },
  classes = { kind = 'Class', keymap = '<leader>lc' },
  interfaces = { kind = 'Interface', keymap = '<leader>li' },
  methods = { kind = 'Method', keymap = '<leader>lm' },
}

-- Python setup  
pickers = {
  functions = { kind = 'Function', keymap = '<leader>lf' },
  classes = { kind = 'Class', keymap = '<leader>lc' },
  variables = { kind = 'Variable', keymap = '<leader>lv' },
}

-- Go setup
pickers = {
  functions = { kind = 'Function', keymap = '<leader>lf' },
  structs = { kind = 'Struct', keymap = '<leader>ls' },
  interfaces = { kind = 'Interface', keymap = '<leader>li' },
  methods = { kind = 'Method', keymap = '<leader>lm' },
}
```

### Custom Picker Examples

#### Error Handling Nodes
```lua
pickers = {
  error_handling = {
    func = function()
      local nodes = {}
      -- Collect try/catch, error returns, etc.
      -- Implementation depends on language
      return nodes
    end,
    keymap = '<leader>le',
    name = 'Error Handling'
  }
}
```

#### Import Statements
```lua
pickers = {
  imports = {
    func = function()
      local nodes = {}
      local parser = vim.treesitter.get_parser(0)
      if not parser then return nodes end
      
      local query = vim.treesitter.query.parse(
        parser:lang(),
        '(import_statement) @import'
      )
      
      for id, node in query:iter_captures(parser:parse()[1]:root(), 0) do
        table.insert(nodes, node)
      end
      
      return nodes
    end,
    keymap = '<leader>li',
    name = 'Imports'
  }
}
```

## 🔍 How It Works

1. **Picker Activation** - When you trigger a picker, Lemur:
   - Collects relevant nodes (via LSP or custom function)
   - Highlights all nodes in the buffer
   - Sets up temporary keymaps for navigation

2. **LSP Integration** - For SymbolKind pickers, Lemur:
   - Requests document symbols from LSP server
   - Filters by the specified SymbolKind
   - Maps LSP ranges to tree-sitter nodes

3. **Navigation** - During sticky mode:
   - `j`/`k` move cursor between collected nodes
   - Navigation wraps around (end → beginning)
   - All nodes remain highlighted

4. **Exit** - When exiting sticky mode:
   - Clears all highlights
   - Removes temporary keymaps
   - Returns to normal editing

## 🐛 Troubleshooting

### LSP Pickers Not Working

- **Check LSP Status**: `:LspInfo` to verify LSP server is running
- **Enable Debug**: `debug = true` in setup to see detailed logs
- **Check SymbolKind**: Some servers don't support all SymbolKind types

### No Nodes Found

- **Tree-sitter**: Verify parser is installed (`:TSInstall <language>`)
- **LSP Symbols**: Some files may not have symbols of the requested type
- **Custom Pickers**: Check your function returns valid tree-sitter nodes

### Highlighting Issues

- **Colorscheme**: Define `LemurTargets` highlight group in your colorscheme
- **Manual Override**: 
  ```lua
  vim.api.nvim_set_hl(0, 'LemurTargets', { bg = '#3e4451', fg = '#abb2bf' })
  ```

### Debug Commands

```vim
:LemurToggleDebug    " Enable detailed logging
:LemurLogs           " View recent debug logs  
:LemurClearLogs      " Clear log history
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

*Happy navigating! 🐒*