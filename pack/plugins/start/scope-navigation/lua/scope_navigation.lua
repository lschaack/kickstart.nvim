-- scope-navigator.lua
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

  -- Tree visualization options
  tree_visualization = {
    max_depth = 20, -- Maximum depth to visualize
    max_node_length = 30, -- Maximum length for node text preview
    show_unnamed_nodes = false, -- Whether to show unnamed nodes
    highlight_navigable = true, -- Highlight navigable nodes
    use_fold_markers = true, -- Use fold markers to make tree collapsible
    show_node_ids = false, -- Show node ids (for debugging)
    node_prefix = '│  ', -- Prefix for node indentation
    last_node_prefix = '└─ ', -- Prefix for last node at level
    middle_node_prefix = '├─ ', -- Prefix for non-last nodes
  },
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

-- Get node text preview from buffer
local function get_node_text_preview(node, bufnr)
  if not node then
    return 'nil'
  end

  local start_row, start_col, end_row, end_col = node:range()
  local max_len = M.config.tree_visualization.max_node_length

  -- For single line nodes
  if start_row == end_row then
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
    local text = line:sub(start_col + 1, end_col)

    -- Trim if too long
    if #text > max_len then
      text = text:sub(1, max_len - 3) .. '...'
    end

    -- Escape special chars
    text = text:gsub('\n', '\\n'):gsub('\t', '\\t'):gsub('\r', '\\r')
    return text
  else
    -- For multi-line nodes, just show first line
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
    local text = line:sub(start_col + 1)

    -- Trim if too long
    if #text > max_len - 5 then
      text = text:sub(1, max_len - 8) .. '...'
    end

    return text .. ' [...]'
  end
end

-- Get unique node ID (for debugging)
local node_id_counter = 0
local node_ids = setmetatable({}, { __mode = 'k' }) -- weak table to avoid memory leaks

local function get_node_id(node)
  if node_ids[node] then
    return node_ids[node]
  end

  node_id_counter = node_id_counter + 1
  node_ids[node] = node_id_counter
  return node_id_counter
end

-- Build tree visualization
local function build_tree_visualization(node, bufnr, depth, is_last, prefix, lines, current_depth)
  if not node then
    return
  end
  if depth > M.config.tree_visualization.max_depth then
    return
  end

  current_depth = current_depth or 0
  local indent = prefix or ''

  -- Skip unnamed nodes if configured to do so
  if not M.config.tree_visualization.show_unnamed_nodes and not node:named() then
    return
  end

  -- Node type and range info
  local node_type = node:type()
  local start_row, start_col, end_row, end_col = node:range()
  local range_str = string.format('(%d:%d-%d:%d)', start_row, start_col, end_row, end_col)

  -- Node text preview
  local text_preview = get_node_text_preview(node, bufnr)

  -- Node ID for debugging
  local id_str = ''
  if M.config.tree_visualization.show_node_ids then
    id_str = string.format('[%d] ', get_node_id(node))
  end

  -- Determine node prefix for tree visualization
  local node_prefix = is_last and M.config.tree_visualization.last_node_prefix or M.config.tree_visualization.middle_node_prefix

  -- Generate line text for this node
  local line = indent .. node_prefix

  -- Add fold marker if enabled
  local has_children = node:named_child_count() > 0
  local fold_marker = ''
  if M.config.tree_visualization.use_fold_markers and has_children then
    fold_marker = ' {{{' .. (depth + 1)
  end

  -- Format with highlighting if it's a navigable node
  local is_nav = is_navigable_node(node)
  local nav_marker = is_nav and '*' or ' '

  -- Create the line text
  local line_text = string.format('%s%s%s %s %s %s%s', line, nav_marker, id_str, node_type, range_str, text_preview, fold_marker)

  -- Add line to output
  table.insert(lines, line_text)

  -- Process children
  local child_count = node:named_child_count()
  if child_count > 0 then
    -- Determine indentation for children
    local child_indent = indent
    if is_last then
      child_indent = child_indent .. '   '
    else
      child_indent = child_indent .. M.config.tree_visualization.node_prefix
    end

    -- Process each child
    for i = 0, child_count - 1 do
      local child = node:named_child(i)
      local is_last_child = (i == child_count - 1)
      build_tree_visualization(child, bufnr, depth + 1, is_last_child, child_indent, lines, current_depth + 1)
    end

    -- Add fold end marker if enabled
    if M.config.tree_visualization.use_fold_markers and has_children then
      table.insert(lines, indent .. string.rep(' ', #node_prefix) .. ' }}}' .. (depth + 1))
    end
  end
end

-- Show tree structure visualization
function M.show_tree_visualization()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo.filetype
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

  -- Create a new scratch buffer for the tree visualization
  local tree_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(tree_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(tree_bufnr, 'filetype', 'tree_explorer')

  -- Build the tree structure
  local lines = {
    'Tree-sitter syntax tree for ' .. vim.fn.expand '%:t' .. ' (' .. ft .. ')',
    '* = Navigable node',
    '-----------------------------------------------------------',
    '',
  }

  build_tree_visualization(root, bufnr, 0, true, '', lines)

  -- Set the buffer content
  vim.api.nvim_buf_set_lines(tree_bufnr, 0, -1, false, lines)

  -- Open in a split
  vim.cmd 'vsplit'
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, tree_bufnr)

  -- Make it read-only
  vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', false)

  -- Set up folding
  if M.config.tree_visualization.use_fold_markers then
    vim.api.nvim_win_set_option(win, 'foldmethod', 'marker')
    vim.api.nvim_command 'normal! zR' -- Open all folds initially
  end

  -- Set up highlighting
  if M.config.tree_visualization.highlight_navigable then
    local ns_id = vim.api.nvim_create_namespace 'scope_navigator_tree'

    -- Create highlight group if it doesn't exist
    vim.cmd [[
      highlight default link ScopeNavigatorNavigable Type
      highlight default link ScopeNavigatorNodeType Identifier
      highlight default link ScopeNavigatorNodeRange Comment
      highlight default link ScopeNavigatorNodeText String
    ]]

    -- Add highlighting for navigable nodes (lines with "*")
    for i, line in ipairs(lines) do
      -- Skip header lines
      if i > 4 then
        local lnum = i - 1

        -- Highlight navigable marker
        if line:match '%*' then
          vim.api.nvim_buf_add_highlight(tree_bufnr, ns_id, 'ScopeNavigatorNavigable', lnum, line:find '%*' - 1, line:find '%*' or -1)
        end

        -- Find node type position (after the marker and optional ID)
        local type_start = line:find '[a-zA-Z_][a-zA-Z0-9_]*%s+%('
        if type_start then
          local type_end = line:find('%s+%(', type_start) - 1
          vim.api.nvim_buf_add_highlight(tree_bufnr, ns_id, 'ScopeNavigatorNodeType', lnum, type_start - 1, type_end)

          -- Highlight range
          local range_start = type_end + 1
          local range_end = line:find('%)', range_start)
          if range_end then
            vim.api.nvim_buf_add_highlight(tree_bufnr, ns_id, 'ScopeNavigatorNodeRange', lnum, range_start, range_end)

            -- Highlight text preview
            local text_start = range_end + 2
            local fold_marker = line:find '%s%{%{%{'
            local text_end = fold_marker and fold_marker - 1 or #line
            vim.api.nvim_buf_add_highlight(tree_bufnr, ns_id, 'ScopeNavigatorNodeText', lnum, text_start, text_end)
          end
        end
      end
    end
  end

  -- Add keymap to highlight corresponding node in source
  vim.keymap.set('n', '<CR>', function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    -- Skip header lines
    if lnum <= 4 then
      return
    end

    local line = vim.api.nvim_buf_get_lines(tree_bufnr, lnum - 1, lnum, false)[1]
    -- Extract the range coordinates
    local range_match = line:match '%((%d+):(%d+)%-(%d+):(%d+)%)'
    if not range_match then
      return
    end

    local start_row, start_col, end_row, end_col = line:match '%((%d+):(%d+)%-(%d+):(%d+)%)'
    if not start_row then
      return
    end

    -- Convert to numbers
    start_row, start_col = tonumber(start_row), tonumber(start_col)

    -- Find window with source buffer
    local source_win = nil
    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win_id) == bufnr then
        source_win = win_id
        break
      end
    end

    -- Jump to source position
    if source_win then
      vim.api.nvim_set_current_win(source_win)
      vim.api.nvim_win_set_cursor(source_win, { start_row + 1, start_col })
      vim.cmd 'normal! zz'

      -- Highlight the node briefly
      local ns_id = vim.api.nvim_create_namespace 'scope_navigator_jump'
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

      for i = start_row, tonumber(end_row) do
        local hl_start = i == start_row and start_col or 0
        local hl_end = i == tonumber(end_row) and tonumber(end_col) or -1
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Search', i, hl_start, hl_end)
      end

      vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end, 1000)
    end
  end, { buffer = tree_bufnr, noremap = true, silent = true, desc = 'Jump to source position' })

  -- Add keymap for focusing a node and its descendants
  vim.keymap.set('n', 'f', function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    -- Skip header lines
    if lnum <= 4 then
      return
    end

    local line = vim.api.nvim_buf_get_lines(tree_bufnr, lnum - 1, lnum, false)[1]
    -- Extract the range coordinates
    local range_match = line:match '%((%d+):(%d+)%-(%d+):(%d+)%)'
    if not range_match then
      return
    end

    local start_row, start_col = line:match '%((%d+):(%d+)%-%d+:%d+%)'
    if not start_row then
      return
    end

    -- Convert to numbers
    start_row, start_col = tonumber(start_row), tonumber(start_col)

    -- Get parser and find node at position
    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then
      return
    end

    local tree = parser:parse()[1]
    if not tree then
      return
    end

    local root = tree:root()
    if not root then
      return
    end

    local target_node = root:named_descendant_for_range(start_row, start_col, start_row, start_col)
    if not target_node then
      return
    end

    -- Create a new buffer with focused tree
    vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(tree_bufnr, 0, -1, false, {
      'Focused Tree View - ' .. target_node:type() .. ' at ' .. start_row .. ':' .. start_col,
      '* = Navigable node',
      '-----------------------------------------------------------',
      '',
    })

    -- Rebuild tree visualization focusing on the selected node
    local lines = {}
    build_tree_visualization(target_node, bufnr, 0, true, '', lines)
    vim.api.nvim_buf_set_lines(tree_bufnr, 4, -1, false, lines)
    vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', false)

    -- Refresh highlighting
    vim.cmd 'redraw'
  end, { buffer = tree_bufnr, noremap = true, silent = true, desc = 'Focus on selected node' })

  -- Add keymap to restore full tree view
  vim.keymap.set('n', 'r', function()
    M.show_tree_visualization()
  end, { buffer = tree_bufnr, noremap = true, silent = true, desc = 'Restore full tree view' })

  -- Add keymap help
  vim.keymap.set('n', '?', function()
    vim.api.nvim_echo({
      { 'Tree Visualization Keymaps:', 'Title' },
      { '\n', '' },
      { '<CR> - Jump to source position', 'Normal' },
      { '\n', '' },
      { 'f    - Focus on selected node', 'Normal' },
      { '\n', '' },
      { 'r    - Restore full tree view', 'Normal' },
      { '\n', '' },
      { '?    - Show this help', 'Normal' },
    }, true, {})
  end, { buffer = tree_bufnr, noremap = true, silent = true, desc = 'Show keymap help' })

  return tree_bufnr
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
  vim.api.nvim_create_user_command('ScopeTree', M.show_tree_visualization, {})
  vim.api.nvim_create_user_command('ScopeHighlight', M.highlight_cursor_node, {})
  vim.api.nvim_create_user_command('ScopeInfo', M.show_node_info, {})
  vim.api.nvim_create_user_command('ScopeGotoType', function(opts)
    M.goto_node_type(opts.args)
  end, { nargs = '?' })

  -- Set up keymaps
  vim.keymap.set('n', M.config.keymap.prev, M.goto_prev_node, { noremap = true, silent = true, desc = 'Go to previous navigable node' })
  vim.keymap.set('n', M.config.keymap.next, M.goto_next_node, { noremap = true, silent = true, desc = 'Go to next navigable node' })
  vim.keymap.set('n', M.config.keymap.out_scope, M.goto_parent_node, { noremap = true, silent = true, desc = 'Go to parent navigable node' })
  vim.keymap.set('n', M.config.keymap.in_scope, M.goto_child_node, { noremap = true, silent = true, desc = 'Go to child navigable node' })

  vim.notify('scope-navigator: Plugin initialized', vim.log.levels.INFO)
end

return M
