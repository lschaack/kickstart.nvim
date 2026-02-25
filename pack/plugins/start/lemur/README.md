# Lemur

> Composable semantic code navigation for Neovim using tree-sitter and LSP

Lemur provides **sticky mode navigation** for moving between semantically related code elements. Its architecture separates **finders** (what to navigate) from **pickers** (how to navigate), inspired by Telescope's composable design. Finders can leverage community-maintained tree-sitter query files to work across dozens of languages with zero language-specific code.

## Quick Start

1. **Activate a finder** using a keymap (e.g., `<leader>ls` for scope boundaries)
2. **Cursor jumps** to the nearest matching node
3. **Navigate** with `j` (next) and `k` (previous)
4. **Exit** with `<Esc>`

## Installation

### Requirements

- Neovim 0.9+
- `nvim-treesitter` (required)

Optional dependencies unlock additional finder factories via community-maintained `.scm` query files:

| Plugin | Query File | Languages | Enables |
|--------|-----------|-----------|---------|
| `nvim-treesitter` (built-in) | `highlights.scm` | 321 | Return statements, function calls, string literals, type annotations, etc. |
| `nvim-treesitter` (built-in) | `locals.scm` | 151 | Function/variable/parameter definitions, scopes, references, imports |
| `nvim-treesitter` (built-in) | `folds.scm` | 217 | All foldable regions (functions, classes, loops, objects) |
| `nvim-treesitter` (built-in) | `indents.scm` | 166 | Indent boundaries |
| `nvim-treesitter-context` | `context.scm` | 86 | Structural context nodes (functions, classes, loops, conditionals) |
| `nvim-treesitter-textobjects` | `textobjects.scm` | 40+ | `@function.outer`, `@class.outer`, `@parameter.outer`, etc. |

### Using lazy.nvim

```lua
{
  dir = '/path/to/lemur',
  name = 'lemur',
  config = function()
    local finders = require 'lemur.finders'

    require('lemur').setup {
      finders = {
        functions = {
          finder = finders.lsp_symbols 'Function',
          keymap = '<leader>lf',
          name = 'Functions',
        },
      },
    }
  end,
}
```

## Architecture

### Finders

A **finder** is a callable that returns a sorted list of tree-sitter nodes for the current buffer. Finder factories create finders:

```lua
local finders = require 'lemur.finders'

-- From tree-sitter queries (leverages community .scm files)
finders.query('locals', 'local.definition.function')
finders.query('context', 'context')
finders.query('textobjects', 'function.outer')

-- From LSP document symbols
finders.lsp_symbols 'Function'
finders.lsp_symbols 'Class'

-- From node type (static)
finders.node_type 'function_declaration'

-- From cursor node type (dynamic, determined at call time)
finders.cursor_type()

-- Custom function
finders.custom(function(bufnr)
  -- return list of tree-sitter nodes
end)

-- Composition
finders.union(finder_a, finder_b)        -- combine results
finders.filter(finder, predicate_fn)     -- filter nodes
finders.intersect(finder_a, finder_b)    -- nodes in both
```

### Pickers

A **picker** defines how the user interacts with finder results. The built-in picker is sticky mode:

```lua
local pickers = require 'lemur.pickers'

pickers.sticky()                                    -- default highlight
pickers.sticky { highlight_group = 'LemurContexts' } -- custom highlight
```

A picker implements:
- `activate(nodes, name)` -- enter the picker UI
- `deactivate()` -- exit the picker UI
- `is_active()` -- returns boolean

### Registration

Finders are registered with keymaps in `setup()`. Each can optionally override the default picker:

```lua
require('lemur').setup {
  picker = pickers.sticky(),  -- default picker for all finders

  finders = {
    my_finder = {
      finder = finders.query('locals', 'local.scope'),
      keymap = '<leader>lo',
      name = 'Scopes',
      picker = pickers.sticky { highlight_group = 'Special' },  -- override
    },
  },
}
```

## Configuration

### Full Example

```lua
local finders = require 'lemur.finders'
local pickers = require 'lemur.pickers'

require('lemur').setup {
  debug = false,

  highlight = {
    highlight_group = 'LemurTargets',
  },

  picker = pickers.sticky(),

  finders = {
    -- LSP symbol finders
    functions = {
      finder = finders.lsp_symbols 'Function',
      keymap = '<leader>lf',
      name = 'Functions',
    },
    classes = {
      finder = finders.lsp_symbols 'Class',
      keymap = '<leader>lc',
      name = 'Classes',
    },

    -- Tree-sitter query finders
    contexts = {
      finder = finders.query('context', 'context'),
      keymap = '<leader>lx',
      name = 'Contexts',
    },
    definitions = {
      finder = finders.union(
        finders.query('locals', 'local.definition.function'),
        finders.query('locals', 'local.definition.method')
      ),
      keymap = '<leader>ld',
      name = 'Definitions',
    },

    -- Composed finders
    todos = {
      finder = finders.filter(
        finders.node_type 'comment',
        function(node, bufnr)
          local text = vim.treesitter.get_node_text(node, bufnr)
          return text:match 'TODO' or text:match 'FIXME'
        end
      ),
      keymap = '<leader>lt',
      name = 'TODO Comments',
    },
  },
}
```

### Built-in Finder

| Name | Default Keymap | Description |
|------|---------------|-------------|
| `scopes` | `<leader>ls` | Scope boundaries (functions, blocks, loops, catch clauses) via `locals.scm` |

## Available Query Groups

The `finders.query(group, capture)` factory can use any `.scm` query file shipped with tree-sitter plugins. Below is a reference of captures available from each query group.

### `highlights.scm` (321 languages)

Shipped with nvim-treesitter. Every semantic token type is a capture.

| Capture | Description |
|---------|-------------|
| `keyword.return` | Return statements |
| `keyword.conditional` | `if`, `else`, `switch`, `case` |
| `keyword.repeat` | `for`, `while`, `repeat`, `do` |
| `function.call` | Function/method call sites |
| `string` | String literals |
| `comment` | Comments |
| `type` | Type identifiers and annotations |
| `type.builtin` | Built-in types (`Object`, `String`, `Array`, etc.) |
| `constant` | `CONSTANT_CASE` identifiers |
| `variable.builtin` | Built-in variables (`arguments`, `self`, `this`, etc.) |
| `function` | Function names at definition sites |
| `variable.parameter` | Function parameter names |
| `operator` | Operators (`+`, `-`, `=`, etc.) |
| `number` | Numeric literals |
| `boolean` | `true`/`false` |

### `locals.scm` (151 languages)

Shipped with nvim-treesitter. Scope and definition tracking.

| Capture | Description |
|---------|-------------|
| `local.definition.function` | Function definitions |
| `local.definition.method` | Method definitions |
| `local.definition.var` | Variable definitions |
| `local.definition.parameter` | Function parameters |
| `local.definition.import` | Import statements (JS/TS) |
| `local.definition.associated` | Associated definitions (e.g., `M.foo`) |
| `local.reference` | All identifier references |
| `local.scope` | Scope boundaries (blocks, functions, loops, catch) |

### `folds.scm` (217 languages)

Shipped with nvim-treesitter. Foldable code regions.

| Capture | Description |
|---------|-------------|
| `fold` | All foldable regions -- functions, classes, loops, conditionals, objects, interfaces, enums |

### `context.scm` (86 languages)

Requires [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context).

| Capture | Description |
|---------|-------------|
| `context` | Structural context nodes -- functions, classes, methods, loops, conditionals, switch cases, object literals |
| `context.end` | End/closing node of a context block |

### `textobjects.scm` (40+ languages)

Requires [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects).

| Capture | Description |
|---------|-------------|
| `function.outer` | Entire function (signature + body) |
| `function.inner` | Function body only |
| `class.outer` | Entire class |
| `class.inner` | Class body only |
| `parameter.outer` | Parameter with separator |
| `parameter.inner` | Parameter value only |
| `conditional.outer` | Entire if/else block |
| `conditional.inner` | Conditional body |
| `loop.outer` | Entire loop |
| `loop.inner` | Loop body |
| `call.outer` | Entire function call |
| `call.inner` | Call arguments only |
| `comment.outer` | Entire comment block |
| `block.outer` | Code block |
| `block.inner` | Block contents |
| `return.outer` | Entire return statement |
| `return.inner` | Return value |
| `assignment.outer` | Entire assignment |
| `assignment.lhs` | Left-hand side |
| `assignment.rhs` | Right-hand side |

### `indents.scm` (166 languages)

Shipped with nvim-treesitter. Indentation boundaries.

| Capture | Description |
|---------|-------------|
| `indent.begin` | Start of indented region |
| `indent.end` | End of indented region |
| `indent.branch` | Branch-like structures (`else`, `end`, `}`) |

## Finder Recipes

### Cross-language definitions (151 languages, no LSP required)

```lua
definitions = {
  finder = finders.union(
    finders.query('locals', 'local.definition.function'),
    finders.query('locals', 'local.definition.method')
  ),
  keymap = '<leader>ld',
  name = 'Definitions',
},
```

### All scope boundaries

```lua
scopes = {
  finder = finders.query('locals', 'local.scope'),
  keymap = '<leader>lo',
  name = 'Scopes',
},
```

### All foldable regions

```lua
folds = {
  finder = finders.query('folds', 'fold'),
  keymap = '<leader>lz',
  name = 'Folds',
},
```

### Return statements

```lua
returns = {
  finder = finders.query('highlights', 'keyword.return'),
  keymap = '<leader>lr',
  name = 'Returns',
},
```

### Function call sites

```lua
calls = {
  finder = finders.query('highlights', 'function.call'),
  keymap = '<leader>lk',
  name = 'Calls',
},
```

### Structural contexts (functions, classes, loops, conditionals)

Requires `nvim-treesitter-context`.

```lua
contexts = {
  finder = finders.query('context', 'context'),
  keymap = '<leader>lx',
  name = 'Contexts',
},
```

### Text object regions

Requires `nvim-treesitter-textobjects`.

```lua
text_functions = {
  finder = finders.query('textobjects', 'function.outer'),
  keymap = '<leader>lf',
  name = 'Functions',
},
```

### Combining LSP + tree-sitter

```lua
all_functions = {
  finder = finders.union(
    finders.lsp_symbols 'Function',
    finders.lsp_symbols 'Method'
  ),
  keymap = '<leader>lf',
  name = 'All Functions',
},
```

### Filtering with a predicate

```lua
exported = {
  finder = finders.filter(
    finders.query('locals', 'local.definition.function'),
    function(node, bufnr)
      local text = vim.treesitter.get_node_text(node, bufnr)
      return text:match '^export'
    end
  ),
  keymap = '<leader>le',
  name = 'Exports',
},
```

## Programmatic API

```lua
local lemur = require 'lemur'
local finders = require 'lemur.finders'

-- Register at runtime
lemur.register('my_finder', {
  finder = finders.query('locals', 'local.scope'),
  keymap = '<leader>lx',
  name = 'Scopes',
})

-- Activate by name
lemur.activate 'functions'

-- Execute a finder directly
local nodes = finders.lsp_symbols('Variable')(0)
```

### Available SymbolKind Values (for `finders.lsp_symbols`)

`File`, `Module`, `Namespace`, `Package`, `Class`, `Method`, `Property`, `Field`, `Constructor`, `Enum`, `Interface`, `Function`, `Variable`, `Constant`, `String`, `Number`, `Boolean`, `Array`, `Object`, `Key`, `Null`, `EnumMember`, `Struct`, `Event`, `Operator`, `TypeParameter`

## Commands

| Command | Description |
|---------|-------------|
| `:LemurToggleDebug` | Toggle debug logging |
| `:LemurLogs` | Show debug log history |
| `:LemurClearLogs` | Clear debug logs |
| `:LemurClearSticky` | Exit sticky mode |

## Backward Compatibility

The old `pickers` config key is still accepted and automatically converted to the new `finders` API:

```lua
-- Old API (still works)
require('lemur').setup {
  pickers = {
    functions = { kind = 'Function', keymap = '<leader>lf' },
    todos = { func = my_function, keymap = '<leader>lt' },
  },
}

-- New API (preferred)
require('lemur').setup {
  finders = {
    functions = {
      finder = finders.lsp_symbols 'Function',
      keymap = '<leader>lf',
      name = 'Functions',
    },
  },
}
```

## Troubleshooting

### No nodes found

- **Tree-sitter**: Verify parser is installed (`:TSInstall <language>`)
- **Query finders**: Check the query file exists for your language (`:echo nvim_get_runtime_file('queries/<lang>/locals.scm', v:false)`)
- **LSP finders**: Verify LSP is running (`:LspInfo`)
- **Enable debug**: Set `debug = true` in setup, then check `:LemurLogs`

### Highlighting issues

Override the default highlight group in your colorscheme:

```lua
vim.api.nvim_set_hl(0, 'LemurTargets', { bg = '#3e4451', fg = '#abb2bf' })
```

## License

MIT
