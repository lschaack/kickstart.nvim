# CLAUDE.md - Lemur Plugin

This file provides guidance to Claude Code when working with the Lemur plugin codebase.

## Overview

Lemur is a Neovim plugin that provides sticky mode navigation using tree-sitter AST nodes. It uses a composable **finder/picker** architecture: finders produce sorted lists of nodes, pickers define the UI for navigating them.

## Architecture

### File Structure

```
lua/lemur/
├── init.lua          -- Setup, registration, public API
├── finders.lua       -- Finder factories and composition
├── pickers/
│   ├── init.lua      -- Picker module (exports sticky factory)
│   └── sticky.lua    -- Sticky mode implementation
└── util.lua          -- Shared helpers (logging, cursor, highlights)
plugin/lemur.lua      -- Deferred auto-setup
init.lua              -- Entry point (re-exports lua/lemur)
```

### Key Components

**Finders** (`lua/lemur/finders.lua`):
- Factories that return `function(bufnr?) -> node[]`
- `query(group, capture)` -- uses community `.scm` query files
- `lsp_symbols(kind)` -- LSP document symbols
- `node_type(type)` -- static tree-sitter node type
- `cursor_type()` -- dynamic, type from node under cursor
- `custom(fn)` -- wraps a user function
- `union(a, b)`, `filter(finder, pred)`, `intersect(a, b)` -- combinators

**Pickers** (`lua/lemur/pickers/`):
- Objects with `activate(nodes, name)`, `deactivate()`, `is_active()`
- `sticky` is the built-in picker (j/k navigation with highlights)

**Util** (`lua/lemur/util.lua`):
- Debug logging (toggle, show, clear)
- Tree-sitter helpers (get_cursor_node, get_tree_root)
- Navigation helpers (find_nearest_node_index, set_cursor_to_node)
- Highlight management (init_highlight_ns, highlight_nodes, clear_highlights)
- Node utilities (sort_nodes_by_position, deduplicate_nodes)

**Init** (`lua/lemur/init.lua`):
- `setup(opts)` -- config, registers finders, creates commands
- `register(name, config)` -- register a finder with optional keymap
- `activate(name)` -- activate a registered finder by name
- Backward compat: old `pickers` config key is auto-converted

### Registration Flow

1. `setup()` creates default picker, registers built-in `scopes` finder on `<leader>ls`
2. User `finders` table entries are registered via `register()`
3. Legacy `pickers` table entries are converted and registered
4. Each `register()` call stores `{finder, picker, name}` in `_registry` and optionally sets a keymap
5. Keymaps call `activate(name)` which runs the finder, then passes nodes to the picker

## Default Behavior

- `<leader>ls` activates the `scopes` finder (scope boundaries via `locals.scm`)
- Sticky mode: `j`/`k` navigate, `<Esc>` exits

## Configuration

```lua
local finders = require 'lemur.finders'
local pickers = require 'lemur.pickers'

require('lemur').setup {
  debug = false,
  highlight = { highlight_group = 'LemurTargets' },
  picker = pickers.sticky(),  -- default picker

  finders = {
    name = {
      finder = finders.query('locals', 'local.scope'),  -- any finder factory
      keymap = '<leader>lx',                              -- optional
      name = 'Display Name',                              -- optional
      picker = pickers.sticky { highlight_group = 'X' },  -- optional override
    },
  },
}
```

## Commands

- `:LemurToggleDebug` -- Toggle debug logging
- `:LemurLogs` -- Show debug log history
- `:LemurClearLogs` -- Clear debug logs
- `:LemurClearSticky` -- Exit sticky mode

## Development Guidelines

- Finder factories return `function(bufnr?) -> node[]`, always sorted by position
- Pickers implement `{activate, deactivate, is_active}`
- Use `util.log_action()` for debug logging
- Use `util.sort_nodes_by_position()` and `util.deduplicate_nodes()` when building finders
- Test navigation on various file types
- Run `stylua --check .` from the nvim config root before committing
