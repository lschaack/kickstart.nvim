-- Example configuration demonstrating the extensible picker system
-- This file shows how to configure Lemur with various picker types

local lemur = require('lemur')

-- Example custom picker function
local function collect_todo_comments()
  local nodes = {}
  local parser = vim.treesitter.get_parser(0)
  if not parser then return nodes end
  
  local tree = parser:parse()[1]
  if not tree then return nodes end
  
  local function traverse(node)
    if node:type() == 'comment' then
      local text = vim.treesitter.get_node_text(node, 0)
      if text and (text:match('TODO') or text:match('FIXME') or text:match('NOTE')) then
        table.insert(nodes, node)
      end
    end
    
    for child in node:iter_children() do
      traverse(child)
    end
  end
  
  traverse(tree:root())
  return nodes
end

-- Example setup with various picker configurations
lemur.setup({
  debug = false, -- Set to true to see debug logs
  
  pickers = {
    -- SymbolKind pickers (string shorthand)
    functions = 'Function',
    variables = 'Variable',
    classes = 'Class',
    
    -- SymbolKind picker with custom keymap
    methods = { 
      kind = 'Method', 
      keymap = '<leader>lm',
      name = 'Class Methods'
    },
    
    -- Custom function picker
    todos = {
      func = collect_todo_comments,
      keymap = '<leader>lt',
      name = 'TODO Comments'
    },
    
    -- Override default same_type picker keymap
    same_type = { keymap = '<leader>ls' },
    
    -- Disable a picker (if it was previously defined)
    -- unwanted_picker = false,
  }
})

-- Example of registering a picker at runtime
lemur.register_picker('constants', {
  kind = 'Constant',
  keymap = '<leader>lc',
  name = 'Constants'
})

-- Example of using a picker programmatically
local function test_picker_programmatically()
  local picker_func = lemur.get_picker('functions')
  if picker_func then
    picker_func() -- This will activate sticky mode for functions
  else
    print('Functions picker not found')
  end
end

-- You can call this function to test programmatic picker usage
-- test_picker_programmatically()

return {
  collect_todo_comments = collect_todo_comments,
  test_picker_programmatically = test_picker_programmatically,
}