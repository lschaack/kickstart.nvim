-- Example configuration demonstrating the finder/picker architecture
-- This file shows how to configure Lemur with various finder types

local finders = require 'lemur.finders'
local pickers = require 'lemur.pickers'

require('lemur').setup {
  debug = false,

  highlight = {
    highlight_group = 'LemurTargets',
  },

  -- Default picker used when none specified per-finder
  picker = pickers.sticky(),

  finders = {
    -- LSP symbol finders
    functions = {
      finder = finders.lsp_symbols 'Function',
      keymap = '<leader>lf',
      name = 'Functions',
    },
    variables = {
      finder = finders.lsp_symbols 'Variable',
      keymap = '<leader>lv',
      name = 'Variables',
    },
    classes = {
      finder = finders.lsp_symbols 'Class',
      keymap = '<leader>lc',
      name = 'Classes',
    },
    methods = {
      finder = finders.lsp_symbols 'Method',
      keymap = '<leader>lm',
      name = 'Methods',
    },

    -- Tree-sitter query finders (cross-language, no LSP required)
    definitions = {
      finder = finders.union(finders.query('locals', 'local.definition.function'), finders.query('locals', 'local.definition.method')),
      keymap = '<leader>ld',
      name = 'Definitions',
    },
    scopes = {
      finder = finders.query('locals', 'local.scope'),
      keymap = '<leader>lo',
      name = 'Scopes',
    },
    contexts = {
      finder = finders.query('context', 'context'),
      keymap = '<leader>lx',
      name = 'Contexts',
    },

    -- Composed finder with filter
    todos = {
      finder = finders.filter(finders.node_type 'comment', function(node, bufnr)
        local text = vim.treesitter.get_node_text(node, bufnr)
        return text and (text:match 'TODO' or text:match 'FIXME' or text:match 'NOTE')
      end),
      keymap = '<leader>lt',
      name = 'TODO Comments',
    },

    -- Per-finder picker override
    folds = {
      finder = finders.query('folds', 'fold'),
      keymap = '<leader>lz',
      name = 'Folds',
      picker = pickers.sticky { highlight_group = 'LemurFolds' },
    },

    -- Override default scopes keymap
    scopes = {
      finder = finders.query('locals', 'local.scope'),
      keymap = '<leader>ls',
      name = 'Scopes',
    },
  },
}

-- Register a finder at runtime
local lemur = require 'lemur'

lemur.register('returns', {
  finder = finders.query('highlights', 'keyword.return'),
  keymap = '<leader>lr',
  name = 'Returns',
})

-- Activate a finder programmatically
local function test_programmatic()
  lemur.activate 'functions'
end

-- Execute a finder directly (returns nodes without activating a picker)
local function test_direct()
  local nodes = finders.lsp_symbols 'Variable'(0)
  print('Found ' .. #nodes .. ' variable nodes')
end

return {
  test_programmatic = test_programmatic,
  test_direct = test_direct,
}
