-- scope-navigator.lua
-- A flexible, node-based Neovim plugin for navigating tree-sitter nodes

-- so the situation is this:
-- when getting the current node from a given position, the built-in util always gets the smallest node.
-- this can be a problem when we choose that node's parent, but the parent is at the same position
-- b/c on the next round, we select the current node from its position and wind up back at the child node again...

local M = {}

-- Cache for performance
local cache = {
  last_node = nil,
  last_bufnr = nil,
  last_loc = { 1, 0 },
}

-- Default configuration
M.config = {
  -- Keymap settings
  keymap = {
    prev = '<leader>sk', -- Previous node (up)
    next = '<leader>sj', -- Next node (down)
    in_scope = '<leader>sl', -- Into node (right)
    out_scope = '<leader>sh', -- Out of node (left)
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

-- FIXME: clean this up
-- TODO: make this auto-open if debug option is passed in
local logger = require 'pack.plugins.start.scope-navigation.lua.logger'
-- Debug print function
local function debug_print(...)
  local statement = string.format('[scope-navigator] %s', ...)
  logger.log(statement)

  if M.config.debug then
    print(statement)
  end
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

  return string.format('%s at %d:%d-%d:%d [%s]', type, start_row, start_col, end_row, end_col, text)
end

local function is_start_pos_equal(node_a, node_b)
  if not node_a or not node_b then
    return false
  end

  local start_row_a, start_col_a, _ = node_a:start()
  local start_row_b, start_col_b, _ = node_b:start()

  -- debug_print('start_row_a == ' .. start_row_a .. ', start_col_a == ' .. start_col_a)
  -- debug_print('start_row_b == ' .. start_row_b .. ', start_col_b == ' .. start_col_b)

  local is_pos_equal = start_row_a == start_row_b and start_col_a == start_col_b

  return is_pos_equal
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
-- FIXME: after getting to the top node, this breaks trying to get parent again
-- FIXME: I think the freezing issue might be related to highlighting?
local function get_current_node()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local has_moved = cache.last_loc and (cursor_pos[1] ~= cache.last_loc[1] or cursor_pos[2] ~= cache.last_loc[2])

  if has_moved then
    debug_print 'updating last location'
    cache.last_loc = cursor_pos
  end

  -- TODO: Remove caching logic if unusable (likely in this form)
  -- Use cached node if available and we're still in the same buffer
  -- if cache.last_node and cache.last_bufnr == bufnr then
  --   -- Verify if cursor is still within the cached node
  --   local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  --   row = row - 1 -- 0-indexed
  --   local start_row, start_col, end_row, end_col = cache.last_node:range()
  --
  --   -- Check if cursor is within the cached node range
  --   if row >= start_row and row <= end_row and (row > start_row or col >= start_col) and (row < end_row or col <= end_col) then
  --     return cache.last_node
  --   end
  -- end
  if cache.last_node and cache.last_bufnr == bufnr and not has_moved then
    return cache.last_node
  end

  -- Get cursor position
  local row, col = unpack(cursor_pos)
  -- debug_print('row ' .. row .. ', col ' .. col)
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

  local current_node = root:named_descendant_for_range(row, col, row, col)

  -- Cache the node for next operation
  cache.last_node = current_node
  cache.last_bufnr = vim.api.nvim_get_current_buf()
  cache.last_cursor_pos = cursor_pos

  return current_node
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
    debug_print 'no parent b/c no node'
    return nil
  end

  local parent = node:parent()

  -- Treat parents with the same start position as the same node
  while parent and not is_navigable_node(parent) do
    parent = parent:parent()
  end

  if not parent then
    debug_print 'no parent b/c no parent'
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
-- TODO: reimplement w/TSNode:next_named_sibling...why didn't claude do this?
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

local function has_navigable_sibling(node)
  local parent = node:parent()

  if not parent then
    return false
  elseif parent:named_child_count() > 1 then
    for i = 0, parent:named_child_count() - 1 do
      if is_navigable_node(parent:named_child(i)) then
        return true
      end
    end

    return false
  else
    return false
  end
end

local function get_first_child_with_sibling(node)
  if not node then
    return nil
  end

  local child = get_child_navigable_node(node)

  while child do
    if has_navigable_sibling(child) then
      return child
    else
      child = get_child_navigable_node(child)
    end
  end

  return nil
end

-- TODO: create parent crawler with predicate and node action params
local function get_next_parent_sibling(node)
  if not node then
    return nil
  end

  local parent = get_parent_navigable_node(node)

  while parent do
    if has_navigable_sibling(parent) then
      return get_next_navigable_node(parent)
    else
      parent = get_parent_navigable_node(parent)
    end
  end

  return nil
end

local function get_prev_parent_sibling(node)
  if not node then
    return nil
  end

  local parent = get_parent_navigable_node(node)

  while parent do
    if has_navigable_sibling(parent) then
      return parent
    else
      parent = get_parent_navigable_node(node)
    end
  end

  return nil
end

local function get_following_navigable_node(node)
  if not node then
    return nil
  end

  local following_node = get_next_navigable_node(node) or get_first_child_with_sibling(node) or get_next_parent_sibling(node)

  return following_node
end

local function get_preceding_navigable_node(node)
  if not node then
    return nil
  end

  local preceding_node = get_prev_navigable_node(node) or get_prev_parent_sibling(node)

  return preceding_node
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
  -- FIXME: Pretty sure this is causing the crashes
  -- FIXME: re-enable if this isn't causing freezing
  -- vim.defer_fn(function()
  --   vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  -- end, M.config.visual.highlight_duration_ms)
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

  return true
end

local function create_goto(goto_func, action)
  return function()
    local current_node = get_current_navigable_node()

    if M.config.debug then
      debug_print('Current: ' .. get_node_info(current_node))
    end

    local target_node = goto_func(current_node)

    if M.config.debug and target_node then
      debug_print('Target:  ' .. get_node_info(target_node))
    end

    if not goto_node(target_node) then
      vim.notify(string.format('No %s node found', action or 'target'), vim.log.levels.INFO)
    end
  end
end

M.goto_prev_node = create_goto(get_prev_navigable_node, 'previous')
M.goto_next_node = create_goto(get_next_navigable_node, 'next')
M.goto_parent_node = create_goto(get_parent_navigable_node, 'parent')
M.goto_child_node = create_goto(get_child_navigable_node, 'child')
M.goto_following_node = create_goto(get_following_navigable_node, 'following')
M.goto_preceding_node = create_goto(get_preceding_navigable_node, 'preceding')

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

-- Show node types in a buffer (old implementation)
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

  -- Add helper text
  table.insert(lines, '')
  table.insert(lines, 'Tip: Use :ScopeTree to see the full tree structure')

  -- Set buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Open in a split
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
end

-- Create highlight node at cursor
function M.highlight_cursor_node()
  local node = get_current_node()
  if not node then
    vim.notify('No node at cursor position', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()

  vim.notify(string.format('Node: %s at %d:%d-%d:%d', node:type(), start_row, start_col, end_row, end_col), vim.log.levels.INFO)

  -- Highlight the node
  local ns_id = vim.api.nvim_create_namespace 'scope_navigator_highlight'
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for i = start_row, end_row do
    local hl_start = i == start_row and start_col or 0
    local hl_end = i == end_row and end_col or -1
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Search', i, hl_start, hl_end)
  end

  -- Clear highlight after timeout
  vim.defer_fn(function()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end, 1500)
end

-- Navigate to a specific node type
function M.goto_node_type(node_type)
  if not node_type or node_type == '' then
    -- Ask user for node type
    vim.ui.input({
      prompt = 'Enter node type: ',
    }, function(input)
      if input and input ~= '' then
        M.goto_node_type(input)
      end
    end)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    vim.notify('No parser available for current buffer', vim.log.levels.ERROR)
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    vim.notify('Failed to parse syntax tree', vim.log.levels.ERROR)
    return
  end

  local root = tree:root()
  if not root then
    vim.notify('No root node found', vim.log.levels.ERROR)
    return
  end

  -- Current cursor position
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1 -- 0-indexed

  -- Find the first occurrence of the specified node type
  local target_node = nil

  -- Recursive function to walk the tree
  local function find_node(node, search_type)
    if not node then
      return nil
    end

    if node:type() == search_type then
      local start_row, start_col, end_row, end_col = node:range()
      -- Check if the node is after current cursor position
      if start_row > row or (start_row == row and start_col > col) then
        return node
      end
    end

    -- Search in children
    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      local found = find_node(child, search_type)
      if found then
        return found
      end
    end

    return nil
  end

  target_node = find_node(root, node_type)

  if not target_node then
    -- If not found after cursor, search from beginning
    local function find_node_from_start(node, search_type)
      if not node then
        return nil
      end

      if node:type() == search_type then
        return node
      end

      -- Search in children
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        local found = find_node_from_start(child, search_type)
        if found then
          return found
        end
      end

      return nil
    end

    target_node = find_node_from_start(root, node_type)
  end

  if target_node then
    goto_node(target_node)
    vim.notify('Found node: ' .. node_type, vim.log.levels.INFO)
  else
    vim.notify("No node of type '" .. node_type .. "' found", vim.log.levels.WARN)
  end
end

-- Show information about node at current cursor position
function M.show_node_info()
  local node = get_current_node()
  if not node then
    vim.notify('No node at cursor position', vim.log.levels.WARN)
    return
  end

  local start_row, start_col, end_row, end_col = node:range()
  local node_type = node:type()
  local is_named = node:named() and 'Yes' or 'No'
  local child_count = node:named_child_count()
  local navigable = is_navigable_node(node) and 'Yes' or 'No'

  -- Get text content
  local bufnr = vim.api.nvim_get_current_buf()
  local text = ''
  if start_row == end_row then
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
    text = line:sub(start_col + 1, end_col)
  else
    text = 'Multiline content...'
  end

  if #text > 30 then
    text = text:sub(1, 27) .. '...'
  end

  -- Get parent and children info
  local parent = node:parent()
  local parent_type = parent and parent:type() or 'None'

  local child_types = {}
  for i = 0, child_count - 1 do
    local child = node:named_child(i)
    table.insert(child_types, child:type())
  end

  -- Display info
  local info = {
    { 'Node Information:', 'Title' },
    { '\n', '' },
    { 'Type: ', 'Label' },
    { node_type, 'Normal' },
    { '\n', '' },
    { 'Range: ', 'Label' },
    { string.format('%d:%d - %d:%d', start_row, start_col, end_row, end_col), 'Normal' },
    { '\n', '' },
    { 'Named: ', 'Label' },
    { is_named, 'Normal' },
    { '\n', '' },
    { 'Navigable: ', 'Label' },
    { navigable, 'Normal' },
    { '\n', '' },
    { 'Child Count: ', 'Label' },
    { tostring(child_count), 'Normal' },
    { '\n', '' },
    { 'Parent Type: ', 'Label' },
    { parent_type, 'Normal' },
    { '\n', '' },
  }

  if #child_types > 0 then
    table.insert(info, { 'Child Types: ', 'Label' })
    table.insert(info, { table.concat(child_types, ', '), 'Normal' })
    table.insert(info, { '\n', '' })
  end

  table.insert(info, { 'Content: ', 'Label' })
  table.insert(info, { '"' .. text .. '"', 'String' })

  vim.api.nvim_echo(info, true, {})

  -- Highlight the node
  highlight_node(node)
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
        elseif k == 'tree_visualization' then
          -- For tree_visualization, do a deep merge
          for k2, v2 in pairs(v) do
            M.config[k][k2] = v2
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
  vim.api.nvim_create_user_command('ScopeHighlight', M.highlight_cursor_node, {})
  vim.api.nvim_create_user_command('ScopeInfo', M.show_node_info, {})
  vim.api.nvim_create_user_command('ScopeLogs', logger.open_log_window, {})
  vim.api.nvim_create_user_command('ScopeGotoType', function(opts)
    M.goto_node_type(opts.args)
  end, { nargs = '?' })

  -- Set up keymaps
  -- vim.keymap.set('n', M.config.keymap.prev, M.goto_prev_node, { noremap = true, silent = true, desc = 'Go to previous navigable node' })
  -- vim.keymap.set('n', M.config.keymap.next, M.goto_next_node, { noremap = true, silent = true, desc = 'Go to next navigable node' })
  -- vim.keymap.set('n', M.config.keymap.out_scope, M.goto_parent_node, { noremap = true, silent = true, desc = 'Go to parent navigable node' })
  -- vim.keymap.set('n', M.config.keymap.in_scope, M.goto_child_node, { noremap = true, silent = true, desc = 'Go to child navigable node' })
  vim.keymap.set('n', M.config.keymap.prev, M.goto_preceding_node, { noremap = true, silent = true, desc = 'Go to preceding navigable node' })
  vim.keymap.set('n', M.config.keymap.next, M.goto_following_node, { noremap = true, silent = true, desc = 'Go to following navigable node' })
  vim.keymap.set('n', M.config.keymap.out_scope, M.goto_parent_node, { noremap = true, silent = true, desc = 'Go to parent navigable node' })
  vim.keymap.set('n', M.config.keymap.in_scope, M.goto_child_node, { noremap = true, silent = true, desc = 'Go to child navigable node' })

  vim.notify('scope-navigator: Plugin initialized', vim.log.levels.INFO)
end

return M
