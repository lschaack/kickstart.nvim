-- Integration test for the extensible picker system
-- Run this in Neovim to test the new functionality

local lemur = require('lemur')

-- Test function to validate the picker system
local function test_extensible_system()
  print('=== Testing Lemur Extensible Picker System ===')
  
  -- Test 1: Basic setup with SymbolKind pickers
  lemur.setup({
    debug = true, -- Enable debug to see what's happening
    pickers = {
      -- Test string shorthand
      test_functions = 'Function',
      
      -- Test explicit config
      test_variables = {
        kind = 'Variable',
        keymap = '<leader>ltv',
        name = 'Test Variables'
      },
      
      -- Test custom function picker
      test_custom = {
        func = function()
          print('Custom picker function called!')
          -- Return some dummy nodes for testing
          local parser = vim.treesitter.get_parser(0)
          if parser then
            local tree = parser:parse()[1]
            if tree then
              return { tree:root():child(0) } -- Return first child as test
            end
          end
          return {}
        end,
        keymap = '<leader>ltc',
        name = 'Test Custom Picker'
      },
      
      -- Test overriding same_type
      same_type = { keymap = '<leader>lts' }
    }
  })
  
  print('✓ Setup completed')
  
  -- Test 2: Check registry contents
  print('\n--- Registry Contents ---')
  for name, config in pairs(lemur.picker_registry) do
    print(string.format('  %s: %s (type: %s)', name, config.name or 'N/A', config.type or 'unknown'))
  end
  
  -- Test 3: Runtime registration
  lemur.register_picker('runtime_test', {
    kind = 'Class',
    keymap = '<leader>ltr',
    name = 'Runtime Test Classes'
  })
  print('✓ Runtime registration completed')
  
  -- Test 4: Programmatic picker retrieval
  local test_picker = lemur.get_picker('test_functions')
  if test_picker then
    print('✓ Picker retrieval works')
  else
    print('✗ Failed to retrieve picker')
  end
  
  -- Test 5: Check if keymaps were registered
  print('\n--- Keymap Tests ---')
  print('Try these keymaps:')
  print('  <leader>ltv - Test Variables picker')
  print('  <leader>ltc - Test Custom picker')
  print('  <leader>lts - Same Type picker (overridden)')
  print('  <leader>ltr - Runtime Test picker')
  
  print('\n=== Test Completed ===')
  print('Use :LemurToggleDebug to toggle debug mode')
  print('Use :LemurLogs to see debug logs')
end

-- Export test function
return {
  test = test_extensible_system
}