-- scope-navigation.lua
-- A flexible, node-based Neovim plugin for navigating tree-sitter nodes

local M = {}

-- Cache for performance
local cache = {
  last_node = nil,
  last_bufnr = nil,
}

-- Default configuration
M.config = {
  -- Keymap settings
  keymap = {
    prev = '<leader>sh', -- Previous node (left)
    next = '<leader>sl', -- Next node (right)
    in_scope = '<leader>sj', -- Into node (down)
    out_scope = '<leader>sk', -- Out of node (up)
  },

  -- Node types to consider as navigable entities
  navigable_nodes = {
    -- Common programming constructs
    'block',
    'function_definition',
    'function_declaration',
    'function',
    'method_definition',
    'class_definition',
    'if_statement',
    'else_clause',
    'for_statement',
    'while_statement',
    'try_statement',
    'catch_clause',
    'do_statement',
    -- TypeScript/JavaScript specific
    'arrow_function',
    'statement_block',
    'else_statement',
    'else_if_statement',
  },

  -- Languages specific node types - will be merged with navigable_nodes
  -- when navigating a file of that filetype
  language_nodes = {
    typescript = {
      'jsx_element',
      'jsx_fragment',
      'export_statement',
      'import_statement',
    },
    python = {
      'with_statement',
      'decorated_definition',
      'class_definition',
      'except_clause',
      'finally_clause',
    },
    rust = {
      'match_arm',
      'match_expression',
      'impl_item',
      'trait_item',
      'mod_item',
    },
    lua = {
      'table_constructor',
      'function_definition',
      'do_statement',
    },
  },

  -- Node matcher function - allows for custom logic beyond just type matching
  -- Return true if the node should be considered navigable
  -- This is executed after checking against navigable_nodes list
  node_matcher = function(node)
    -- Default implementation: no additional matching
    return false
  end,

  -- Visual feedback options
  visual = {
    highlight_node = true, -- Briefly highlight the node when navigating to it
    highlight_duration_ms = 300, -- Milliseconds to show highlight
    highlight_group = 'CursorLine', -- Highlight group to use
  },

  -- Debug settings
  debug = false, -- Set to true to show debug messages
}

-- Debug print function
local function debug_print(...)
  if M.config.debug then
    print(string.format('[scope-navigator] %s', ...))
  end
end

-- Check if a node type is in our navigable nodes list
local function is_navigable_node(node)
  if not node then
    return false
  end

  local node_type = node:type()
  local ft = vim.bo.filetype

  -- Check against base navigable nodes
  for _, nav_type in ipairs(M.config.navigable_nodes) do
    if node_type == nav_type then
      return true
    end
  end

  -- Check against language-specific nodes if available
  if M.config.language_nodes[ft] then
    for _, nav_type in ipairs(M.config.language_nodes[ft]) do
      if node_type == nav_type then
        return true
      end
    end
  end

  -- Try custom matcher function as fallback
  return M.config.node_matcher(node)
end

-- Get the current node at cursor position
local function get_current_node()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Use cached node if available and we're still in the same buffer
  if cache.last_node and cache.last_bufnr == bufnr then
    -- Verify if cursor is still within the cached node
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1 -- 0-indexed
    local start_row, start_col, end_row, end_col = cache.last_node:range()

    -- Check if cursor is within the cached node range
    if row >= start_row and row <= end_row and (row > start_row or col >= start_col) and (row < end_row or col <= end_col) then
      return cache.last_node
    end
  end

  -- Get cursor position
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1 -- 0-indexed

  -- Get parser for current buffer
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    debug_print 'No parser available for buffer'
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    debug_print 'No syntax tree available'
    return nil
  end

  local root = tree:root()
  if not root then
    debug_print 'No root node available'
    return nil
  end

  return root:named_descendant_for_range(row, col, row, col)
end

-- Find the closest navigable node from current position
local function get_current_navigable_node()
  local current_node = get_current_node()
  if not current_node then
    debug_print 'No node at cursor position'
    return nil
  end

  -- Walk up the tree to find a navigable node
  local node = current_node
  while node and not is_navigable_node(node) do
    node = node:parent()
  end

  return node
end

-- Find parent navigable node
local function get_parent_navigable_node(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  while parent and not is_navigable_node(parent) do
    parent = parent:parent()
  end

  return parent
end

-- Get first navigable child node
local function get_child_navigable_node(node)
  if not node then
    return nil
  end

  -- Check immediate children first
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if is_navigable_node(child) then
      return child
    end
  end

  -- If no immediate navigable children, search deeper recursively
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    local navigable_descendant = get_child_navigable_node(child)
    if navigable_descendant then
      return navigable_descendant
    end
  end

  return nil
end

-- Find previous sibling navigable node
local function get_prev_navigable_node(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  if not parent then
    return nil
  end

  local prev_navigable = nil
  local found_current = false

  -- Loop through children to find the previous navigable node
  for i = 0, parent:named_child_count() - 1 do
    local child = parent:named_child(i)

    if child == node then
      found_current = true
      break
    elseif is_navigable_node(child) then
      prev_navigable = child
    end
  end

  return prev_navigable
end

-- Find next sibling navigable node
local function get_next_navigable_node(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  if not parent then
    return nil
  end

  local found_current = false

  -- Loop through children to find the next navigable node
  for i = 0, parent:named_child_count() - 1 do
    local child = parent:named_child(i)

    if found_current and is_navigable_node(child) then
      return child
    elseif child == node then
      found_current = true
    end
  end

  return nil
end

-- Highlight a node temporarily for visual feedback
local function highlight_node(node)
  if not node or not M.config.visual.highlight_node then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()

  -- Create namespace for highlights if it doesn't exist
  local ns_id = vim.api.nvim_create_namespace 'scope_navigator'

  -- Add highlight
  vim.api.nvim_buf_add_highlight(bufnr, ns_id, M.config.visual.highlight_group, start_row, start_col, end_col)

  -- Clear highlight after timeout
  vim.defer_fn(function()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end, M.config.visual.highlight_duration_ms)
end

-- Navigate to a node
local function goto_node(node)
  if not node then
    debug_print 'No target node found'
    return false
  end

  -- Get node position
  local start_row, start_col, _, _ = node:range()
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })

  -- Center view if node is off-screen
  vim.cmd 'normal! zz'

  -- Provide visual feedback
  highlight_node(node)

  -- Cache the node for next operation
  cache.last_node = node
  cache.last_bufnr = vim.api.nvim_get_current_buf()

  return true
end

-- Get node info for debugging
local function get_node_info(node)
  if not node then
    return 'No node'
  end

  local start_row, start_col, end_row, end_col = node:range()
  local type = node:type()
  local text = vim.api.nvim_buf_get_text(vim.api.nvim_get_current_buf(), start_row, start_col, start_row, start_col + 10, {})[1] or ''

  if #text > 10 then
    text = text:sub(1, 10) .. '...'
  end

  return string.format('Node: %s at %d:%d-%d:%d [%s]', type, start_row, start_col, end_row, end_col, text)
end

-- Command implementations
function M.goto_prev_node()
  local current_node = get_current_navigable_node()

  if M.config.debug then
    debug_print('Current: ' .. get_node_info(current_node))
  end

  local prev_node = get_prev_navigable_node(current_node)

  if M.config.debug and prev_node then
    debug_print('Target: ' .. get_node_info(prev_node))
  end

  if not goto_node(prev_node) then
    vim.notify('No previous navigable node found', vim.log.levels.INFO)
  end
end

function M.goto_next_node()
  local current_node = get_current_navigable_node()

  if M.config.debug then
    debug_print('Current: ' .. get_node_info(current_node))
  end

  local next_node = get_next_navigable_node(current_node)

  if M.config.debug and next_node then
    debug_print('Target: ' .. get_node_info(next_node))
  end

  if not goto_node(next_node) then
    vim.notify('No next navigable node found', vim.log.levels.INFO)
  end
end

function M.goto_parent_node()
  local current_node = get_current_navigable_node()

  if M.config.debug then
    debug_print('Current: ' .. get_node_info(current_node))
  end

  local parent_node = get_parent_navigable_node(current_node)

  if M.config.debug and parent_node then
    debug_print('Target: ' .. get_node_info(parent_node))
  end

  if not goto_node(parent_node) then
    vim.notify('No parent navigable node found', vim.log.levels.INFO)
  end
end

function M.goto_child_node()
  local current_node = get_current_navigable_node()

  if M.config.debug then
    debug_print('Current: ' .. get_node_info(current_node))
  end

  local child_node = get_child_navigable_node(current_node)

  if M.config.debug and child_node then
    debug_print('Target: ' .. get_node_info(child_node))
  end

  if not goto_node(child_node) then
    vim.notify('No child navigable node found', vim.log.levels.INFO)
  end
end

-- Get a list of all node types in the current buffer
function M.list_node_types()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  if not root then
    return {}
  end

  local node_types = {}
  local function collect_types(node)
    if not node then
      return
    end

    local node_type = node:type()
    node_types[node_type] = (node_types[node_type] or 0) + 1

    for child in node:iter_children() do
      collect_types(child)
    end
  end

  collect_types(root)

  -- Convert to sorted list
  local types_list = {}
  for t, count in pairs(node_types) do
    table.insert(types_list, { type = t, count = count })
  end

  table.sort(types_list, function(a, b)
    return a.count > b.count
  end)

  return types_list
end

-- Show node types in a buffer
function M.show_node_types()
  local types = M.list_node_types()

  -- Create a new scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')

  -- Format node types
  local lines = { 'Node types in current buffer:', '' }
  for _, item in ipairs(types) do
    table.insert(lines, string.format('%s (%d occurrences)', item.type, item.count))
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Open in a split
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
end

-- Setup function
function M.setup(user_config)
  -- Merge user config with defaults
  if user_config then
    -- Handle simple key replacements
    for k, v in pairs(user_config) do
      if type(v) ~= 'table' or k == 'node_matcher' then
        M.config[k] = v
      elseif type(v) == 'table' and type(M.config[k]) == 'table' then
        -- Handle nested tables with deep merge
        if k == 'language_nodes' then
          -- For language_nodes, merge the language-specific lists
          for lang, nodes in pairs(v) do
            M.config[k][lang] = M.config[k][lang] or {}
            for _, node_type in ipairs(nodes) do
              table.insert(M.config[k][lang], node_type)
            end
          end
        else
          -- For other tables, do a simple merge
          for k2, v2 in pairs(v) do
            M.config[k][k2] = v2
          end
        end
      end
    end
  end

  -- Check if tree-sitter is available
  if not pcall(require, 'nvim-treesitter') then
    vim.notify('scope-navigator: nvim-treesitter not found. Please install it first.', vim.log.levels.ERROR)
    return
  end

  -- Create user commands
  vim.api.nvim_create_user_command('ScopePrev', M.goto_prev_node, {})
  vim.api.nvim_create_user_command('ScopeNext', M.goto_next_node, {})
  vim.api.nvim_create_user_command('ScopeParent', M.goto_parent_node, {})
  vim.api.nvim_create_user_command('ScopeChild', M.goto_child_node, {})
  vim.api.nvim_create_user_command('ScopeNodeTypes', M.show_node_types, {})

  -- Set up keymaps
  vim.keymap.set('n', M.config.keymap.prev, M.goto_prev_node, { noremap = true, silent = true, desc = 'Go to previous navigable node' })
  vim.keymap.set('n', M.config.keymap.next, M.goto_next_node, { noremap = true, silent = true, desc = 'Go to next navigable node' })
  vim.keymap.set('n', M.config.keymap.out_scope, M.goto_parent_node, { noremap = true, silent = true, desc = 'Go to parent navigable node' })
  vim.keymap.set('n', M.config.keymap.in_scope, M.goto_child_node, { noremap = true, silent = true, desc = 'Go to child navigable node' })

  vim.notify('scope-navigator: Plugin initialized', vim.log.levels.INFO)
end

return M
