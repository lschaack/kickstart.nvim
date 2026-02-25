-- Integration test for the finder/picker architecture
-- Run this in Neovim to test the new functionality

local lemur = require 'lemur'
local finders = require 'lemur.finders'

local function test_finder_system()
  print '=== Testing Lemur Finder/Picker System ==='

  -- Test 1: Setup with various finder types
  lemur.setup {
    debug = true,
    finders = {
      test_functions = {
        finder = finders.lsp_symbols 'Function',
        keymap = '<leader>ltf',
        name = 'Test Functions',
      },
      test_variables = {
        finder = finders.lsp_symbols 'Variable',
        keymap = '<leader>ltv',
        name = 'Test Variables',
      },
      test_custom = {
        finder = finders.custom(function(bufnr)
          local parser = vim.treesitter.get_parser(bufnr)
          if parser then
            local tree = parser:parse()[1]
            if tree then
              return { tree:root():child(0) }
            end
          end
          return {}
        end),
        keymap = '<leader>ltc',
        name = 'Test Custom',
      },
      scopes = {
        finder = finders.query('locals', 'local.scope'),
        keymap = '<leader>lts',
        name = 'Scopes (overridden)',
      },
    },
  }

  print '  Setup completed'

  -- Test 2: Check registry contents
  print '\n--- Registry Contents ---'
  for name, entry in pairs(lemur._registry) do
    print(string.format('  %s: %s', name, entry.name))
  end

  -- Test 3: Runtime registration
  lemur.register('runtime_test', {
    finder = finders.lsp_symbols 'Class',
    keymap = '<leader>ltr',
    name = 'Runtime Test Classes',
  })
  print '  Runtime registration completed'

  -- Test 4: Direct finder execution
  local cursor_finder = finders.cursor_type()
  local nodes = cursor_finder(0)
  print(string.format('  cursor_type finder returned %d nodes', #nodes))

  -- Test 5: Composition
  local combined = finders.union(finders.lsp_symbols 'Function', finders.lsp_symbols 'Method')
  local combined_nodes = combined(0)
  print(string.format('  union finder returned %d nodes', #combined_nodes))

  print '\n--- Keymap Tests ---'
  print 'Try these keymaps:'
  print '  <leader>ltf - Test Functions'
  print '  <leader>ltv - Test Variables'
  print '  <leader>ltc - Test Custom'
  print '  <leader>lts - Scopes (overridden)'
  print '  <leader>ltr - Runtime Test Classes'

  print '\n=== Test Completed ==='
end

return {
  test = test_finder_system,
}
