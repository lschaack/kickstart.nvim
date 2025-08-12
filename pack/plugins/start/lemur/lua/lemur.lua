local M = {}

M.debug = false
M.logs = {}
M.last_node = nil
M.highlight_ns = nil
M.last_function = nil
M.highlight_timer = nil

M.config = {
  keymaps = {
    move_next_preorder = '<M-j>',
    move_prev_preorder = '<M-k>',
    move_next_levelorder = '<M-l>',
    move_prev_levelorder = '<M-h>',
    move_next_preorder_same_type = '<M-S-j>',
    move_prev_preorder_same_type = '<M-S-k>',
    move_next_preorder_different_line = '<M-C-j>',
    move_prev_preorder_different_line = '<M-C-k>',
    move_next_preorder_same_type_different_line = '<M-C-S-j>',
    move_prev_preorder_same_type_different_line = '<M-C-S-k>',
  },
  highlight = {
    enabled = false,
    highlight_group = 'LemurTargets',
    clear_delay_ms = 3000, -- Auto-clear highlights after 3 seconds
  },
}

local function log_action(action, reason, node_info)
  if not M.debug then
    return
  end

  local timestamp = os.date '%H:%M:%S'
  local entry = string.format('[%s] %s: %s (%s)', timestamp, action, reason, node_info or 'unknown')

  table.insert(M.logs, entry)

  if #M.logs > 100 then
    table.remove(M.logs, 1)
  end

  print(entry)
end

local function get_node_info(node)
  if not node then
    return 'nil'
  end

  local row, col = node:start()
  local node_type = node:type()
  return string.format('%s@%d:%d', node_type, row + 1, col)
end

function M.toggle_debug()
  M.debug = not M.debug
  print('Lemur debug mode: ' .. (M.debug and 'enabled' or 'disabled'))
end

function M.show_logs()
  if #M.logs == 0 then
    print 'No debug logs available'
    return
  end

  print '=== Lemur Debug Logs ==='
  for _, log in ipairs(M.logs) do
    print(log)
  end
  print '========================'
end

function M.clear_logs()
  M.logs = {}
  print 'Lemur debug logs cleared'
end

-- Highlight management functions (moved before setup to avoid forward reference issues)
local function clear_highlights()
  if M.highlight_ns then
    vim.api.nvim_buf_clear_namespace(0, M.highlight_ns, 0, -1)
  end
  
  if M.highlight_timer then
    M.highlight_timer:stop()
    M.highlight_timer = nil
  end
end

local function highlight_node(node)
  if not M.config.highlight.enabled or not M.highlight_ns or not node then
    return
  end
  
  local start_row, start_col = node:start()
  local end_row, end_col = node:end_()
  
  vim.api.nvim_buf_add_highlight(0, M.highlight_ns, M.config.highlight.highlight_group, start_row, start_col, end_col)
end

local function highlight_nodes_with_auto_clear(nodes, function_name)
  if not M.config.highlight.enabled then
    return
  end
  
  clear_highlights()
  M.last_function = function_name
  
  for _, node in ipairs(nodes) do
    highlight_node(node)
  end
  
  -- Set up auto-clear timer
  if M.config.highlight.clear_delay_ms > 0 then
    M.highlight_timer = vim.loop.new_timer()
    M.highlight_timer:start(M.config.highlight.clear_delay_ms, 0, vim.schedule_wrap(function()
      clear_highlights()
    end))
  end
end


function M.setup(opts)
  opts = opts or {}

  -- Merge user config with defaults
  if opts.keymaps then
    M.config.keymaps = vim.tbl_deep_extend('force', M.config.keymaps, opts.keymaps)
  end
  if opts.highlight then
    M.config.highlight = vim.tbl_deep_extend('force', M.config.highlight, opts.highlight)
  end

  -- Create highlight namespace
  M.highlight_ns = vim.api.nvim_create_namespace('lemur_highlights')
  
  -- Set up highlight group
  vim.api.nvim_set_hl(0, M.config.highlight.highlight_group, {
    bg = '#3e4451',
    fg = '#abb2bf',
    default = true
  })

  -- Set up keymaps
  vim.keymap.set('n', M.config.keymaps.move_next_preorder, M.move_next_preorder, { desc = 'Lemur: Move to next node in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_prev_preorder, M.move_prev_preorder, { desc = 'Lemur: Move to previous node in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_next_levelorder, M.move_next_levelorder, { desc = 'Lemur: Move to next node in level-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_prev_levelorder, M.move_prev_levelorder, { desc = 'Lemur: Move to previous node in level-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_next_preorder_same_type, M.move_next_preorder_same_type, { desc = 'Lemur: Move to next node of same type in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_prev_preorder_same_type, M.move_prev_preorder_same_type, { desc = 'Lemur: Move to previous node of same type in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_next_preorder_different_line, M.move_next_preorder_different_line, { desc = 'Lemur: Move to next node on different line in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_prev_preorder_different_line, M.move_prev_preorder_different_line, { desc = 'Lemur: Move to previous node on different line in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_next_preorder_same_type_different_line, M.move_next_preorder_same_type_different_line, { desc = 'Lemur: Move to next node of same type on different line in pre-order traversal' })
  vim.keymap.set('n', M.config.keymaps.move_prev_preorder_same_type_different_line, M.move_prev_preorder_same_type_different_line, { desc = 'Lemur: Move to previous node of same type on different line in pre-order traversal' })

  -- Set up commands
  vim.api.nvim_create_user_command('LemurToggleDebug', M.toggle_debug, { desc = 'Toggle lemur debug mode' })
  vim.api.nvim_create_user_command('LemurLogs', M.show_logs, { desc = 'Show lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearLogs', M.clear_logs, { desc = 'Clear lemur debug logs' })
  vim.api.nvim_create_user_command('LemurToggleHighlight', function()
    M.config.highlight.enabled = not M.config.highlight.enabled
    if not M.config.highlight.enabled then
      clear_highlights()
    end
    print('Lemur highlighting: ' .. (M.config.highlight.enabled and 'enabled' or 'disabled'))
  end, { desc = 'Toggle lemur highlighting' })
  vim.api.nvim_create_user_command('LemurClearHighlight', clear_highlights, { desc = 'Clear lemur highlights' })
  vim.api.nvim_create_user_command('LemurShowReachable', function()
    if M.last_function then
      local nodes = get_reachable_nodes(M.last_function)
      highlight_nodes_with_auto_clear(nodes, M.last_function)
      print('Highlighting ' .. #nodes .. ' reachable nodes for ' .. M.last_function)
    else
      print('No last function recorded')
    end
  end, { desc = 'Show nodes reachable by last used function' })

  if opts.debug then
    M.toggle_debug()
  end
end

local function nodes_equal(node1, node2)
  if not node1 or not node2 then
    return node1 == node2
  end

  local r1, c1 = node1:start()
  local r2, c2 = node2:start()
  local er1, ec1 = node1:end_()
  local er2, ec2 = node2:end_()

  return r1 == r2 and c1 == c2 and er1 == er2 and ec1 == ec2 and node1:type() == node2:type()
end

local function get_cursor_node()
  local ts = vim.treesitter
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local parser = ts.get_parser(0)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local node = tree:root():named_descendant_for_range(row, col, row, col)

  -- If we're at the same position as the last node but got a different node,
  -- it might be a parent/child at the same position. Try to use the previous node
  -- if it's still valid and at the same position.
  if M.last_node and node and not nodes_equal(node, M.last_node) then
    local last_start_row, last_start_col = M.last_node:start()
    local curr_start_row, curr_start_col = node:start()

    if last_start_row == curr_start_row and last_start_col == curr_start_col then
      -- Check if the last node is still valid and contains the cursor
      local last_end_row, last_end_col = M.last_node:end_()
      if row >= last_start_row and row <= last_end_row and (row > last_start_row or col >= last_start_col) and (row < last_end_row or col < last_end_col) then
        return M.last_node
      end
    end
  end

  return node
end

local function set_cursor_to_node(node)
  if not node then
    return
  end

  M.last_node = node
  local start_row, start_col = node:start()
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
end

local function find_meaningful_position(node)
  if not node then
    return nil, nil
  end

  local start_row, start_col = node:start()
  local end_row, end_col = node:end_()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row, current_col = cursor[1] - 1, cursor[2]

  -- If we're not at the start of the node, move to the start
  if current_row ~= start_row or current_col ~= start_col then
    return start_row, start_col
  end

  -- If we're at the start and it's a multi-line node, try the end
  if end_row ~= start_row then
    return end_row, end_col
  end

  -- For single-line nodes, try to find a child at a different position
  for child in node:iter_children() do
    if child:named() then
      local child_start_row, child_start_col = child:start()
      if child_start_row ~= start_row or child_start_col ~= start_col then
        return child_start_row, child_start_col
      end
    end
  end

  -- Last resort: try the end position
  return end_row, end_col
end

local function move_to_parent_with_fallback(node)
  if not node then
    return false
  end

  local parent = node:parent()
  if not parent then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row, current_col = cursor[1] - 1, cursor[2]

  -- Try to find a meaningful position in the parent
  local new_row, new_col = find_meaningful_position(parent)

  if new_row and (new_row ~= current_row or new_col ~= current_col) then
    M.last_node = parent
    vim.api.nvim_win_set_cursor(0, { new_row + 1, new_col })
    return true
  end

  -- If parent doesn't give us a different position, try parent's next sibling
  local parent_next = get_next_sibling(parent)
  if parent_next then
    set_cursor_to_node(parent_next)
    return true
  end

  -- Try parent's parent
  local grandparent = parent:parent()
  if grandparent then
    local gp_row, gp_col = find_meaningful_position(grandparent)
    if gp_row and (gp_row ~= current_row or gp_col ~= current_col) then
      M.last_node = grandparent
      vim.api.nvim_win_set_cursor(0, { gp_row + 1, gp_col })
      return true
    end
  end

  return false
end

local function get_next_sibling(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  if not parent then
    return nil
  end

  local found_self = false
  for child in parent:iter_children() do
    if found_self and child:named() then
      return child
    end
    if child == node then
      found_self = true
    end
  end

  return nil
end

local function get_prev_sibling(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  if not parent then
    return nil
  end

  local prev_sibling = nil
  for child in parent:iter_children() do
    if child == node then
      return prev_sibling
    end
    if child:named() then
      prev_sibling = child
    end
  end

  return nil
end

local function get_first_child(node)
  if not node then
    return nil
  end

  for child in node:iter_children() do
    if child:named() then
      return child
    end
  end

  return nil
end

local function find_next_sibling_up_tree(node)
  if not node then
    return nil
  end

  local current = node
  while current do
    local next_sibling = get_next_sibling(current)
    if next_sibling then
      return next_sibling
    end
    current = current:parent()
  end

  return nil
end

local function get_tree_root()
  local ts = vim.treesitter
  local parser = ts.get_parser(0)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  return tree:root()
end

local function collect_all_nodes(root)
  local nodes = {}
  
  local function traverse(node)
    if node:named() then
      table.insert(nodes, node)
    end
    
    for child in node:iter_children() do
      traverse(child)
    end
  end
  
  if root then
    traverse(root)
  end
  
  return nodes
end

local function collect_nodes_by_type(root, target_type)
  local nodes = {}
  
  local function traverse(node)
    if node:named() and node:type() == target_type then
      table.insert(nodes, node)
    end
    
    for child in node:iter_children() do
      traverse(child)
    end
  end
  
  if root then
    traverse(root)
  end
  
  return nodes
end

local function get_reachable_nodes(function_name)
  local root = get_tree_root()
  if not root then
    return {}
  end
  
  if function_name == 'move_next_preorder' or function_name == 'move_prev_preorder' or function_name == 'move_next_preorder_different_line' or function_name == 'move_prev_preorder_different_line' then
    return collect_all_nodes(root)
  elseif function_name == 'move_next_levelorder' or function_name == 'move_prev_levelorder' then
    return collect_all_nodes_levelorder(root)
  elseif function_name == 'move_next_preorder_same_type' or function_name == 'move_prev_preorder_same_type' or function_name == 'move_next_preorder_same_type_different_line' or function_name == 'move_prev_preorder_same_type_different_line' then
    local current_node = get_cursor_node()
    if current_node then
      return collect_nodes_by_type(root, current_node:type())
    end
  end
  
  return {}
end

local function get_next_preorder(current_node)
  if not current_node then
    return nil
  end

  local root = get_tree_root()
  if not root then
    return nil
  end

  local all_nodes = collect_all_nodes(root)
  
  for i, node in ipairs(all_nodes) do
    if nodes_equal(node, current_node) and i < #all_nodes then
      return all_nodes[i + 1]
    end
  end
  
  return nil
end

local function get_prev_preorder(current_node)
  if not current_node then
    return nil
  end

  local root = get_tree_root()
  if not root then
    return nil
  end

  local all_nodes = collect_all_nodes(root)
  
  for i, node in ipairs(all_nodes) do
    if nodes_equal(node, current_node) and i > 1 then
      return all_nodes[i - 1]
    end
  end
  
  return nil
end

local function collect_all_nodes_levelorder(root)
  local nodes = {}
  
  if not root then
    return nodes
  end
  
  local queue = {}
  table.insert(queue, root)
  
  while #queue > 0 do
    local current = table.remove(queue, 1)
    
    if current:named() then
      table.insert(nodes, current)
    end
    
    for child in current:iter_children() do
      table.insert(queue, child)
    end
  end
  
  return nodes
end

local function get_next_levelorder(current_node)
  if not current_node then
    return nil
  end

  local root = get_tree_root()
  if not root then
    return nil
  end

  local all_nodes = collect_all_nodes_levelorder(root)
  
  for i, node in ipairs(all_nodes) do
    if nodes_equal(node, current_node) and i < #all_nodes then
      return all_nodes[i + 1]
    end
  end
  
  return nil
end

local function get_prev_levelorder(current_node)
  if not current_node then
    return nil
  end

  local root = get_tree_root()
  if not root then
    return nil
  end

  local all_nodes = collect_all_nodes_levelorder(root)
  
  for i, node in ipairs(all_nodes) do
    if nodes_equal(node, current_node) and i > 1 then
      return all_nodes[i - 1]
    end
  end
  
  return nil
end


function M.move_next_preorder()
  local node = get_cursor_node()
  if not node then
    log_action('move_next_preorder', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row, initial_col = initial_cursor[1] - 1, initial_cursor[2]
  local current_node = node
  local attempts = 0
  local max_attempts = 20 -- Prevent infinite loops
  
  local current_info = get_node_info(current_node)
  
  while attempts < max_attempts do
    local next_node = get_next_preorder(current_node)
    if not next_node then
      log_action('move_next_preorder', 'no next node in pre-order traversal', current_info)
      return
    end
    
    local next_start_row, next_start_col = next_node:start()
    
    -- If the next node starts at a different position, move there
    if next_start_row ~= initial_row or next_start_col ~= initial_col then
      local target_info = get_node_info(next_node)
      log_action('move_next_preorder', 'found node at different position after ' .. (attempts + 1) .. ' attempts', current_info .. ' -> ' .. target_info)
      set_cursor_to_node(next_node)
      
      -- Highlight reachable nodes
      local reachable = get_reachable_nodes('move_next_preorder')
      highlight_nodes_with_auto_clear(reachable, 'move_next_preorder')
      return
    end
    
    -- Continue to the next node
    current_node = next_node
    attempts = attempts + 1
  end
  
  log_action('move_next_preorder', 'reached max attempts without finding different position', current_info)
end


function M.move_prev_preorder()
  local node = get_cursor_node()
  if not node then
    log_action('move_prev_preorder', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row, initial_col = initial_cursor[1] - 1, initial_cursor[2]
  local current_node = node
  local attempts = 0
  local max_attempts = 20 -- Prevent infinite loops
  
  local current_info = get_node_info(current_node)
  
  while attempts < max_attempts do
    local prev_node = get_prev_preorder(current_node)
    if not prev_node then
      log_action('move_prev_preorder', 'no previous node in pre-order traversal', current_info)
      return
    end
    
    local prev_start_row, prev_start_col = prev_node:start()
    
    -- If the previous node starts at a different position, move there
    if prev_start_row ~= initial_row or prev_start_col ~= initial_col then
      local target_info = get_node_info(prev_node)
      log_action('move_prev_preorder', 'found node at different position after ' .. (attempts + 1) .. ' attempts', current_info .. ' -> ' .. target_info)
      set_cursor_to_node(prev_node)
      
      -- Highlight reachable nodes
      local reachable = get_reachable_nodes('move_prev_preorder')
      highlight_nodes_with_auto_clear(reachable, 'move_prev_preorder')
      return
    end
    
    -- Continue to the previous node
    current_node = prev_node
    attempts = attempts + 1
  end
  
  log_action('move_prev_preorder', 'reached max attempts without finding different position', current_info)
end


function M.move_next_levelorder()
  local node = get_cursor_node()
  if not node then
    log_action('move_next_levelorder', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  local next_node = get_next_levelorder(node)
  if next_node then
    local target_info = get_node_info(next_node)
    log_action('move_next_levelorder', 'next node in level-order traversal', current_info .. ' -> ' .. target_info)
    set_cursor_to_node(next_node)
    
    -- Highlight reachable nodes
    local reachable = get_reachable_nodes('move_next_levelorder')
    highlight_nodes_with_auto_clear(reachable, 'move_next_levelorder')
  else
    log_action('move_next_levelorder', 'no next node in level-order traversal', current_info)
  end
end


function M.move_prev_levelorder()
  local node = get_cursor_node()
  if not node then
    log_action('move_prev_levelorder', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  local prev_node = get_prev_levelorder(node)
  if prev_node then
    local target_info = get_node_info(prev_node)
    log_action('move_prev_levelorder', 'previous node in level-order traversal', current_info .. ' -> ' .. target_info)
    set_cursor_to_node(prev_node)
    
    -- Highlight reachable nodes
    local reachable = get_reachable_nodes('move_prev_levelorder')
    highlight_nodes_with_auto_clear(reachable, 'move_prev_levelorder')
  else
    log_action('move_prev_levelorder', 'no previous node in level-order traversal', current_info)
  end
end

function M.move_next_preorder_same_type()
  local node = get_cursor_node()
  if not node then
    log_action('move_next_preorder_same_type', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row, initial_col = initial_cursor[1] - 1, initial_cursor[2]
  local target_type = node:type()
  local current_info = get_node_info(node)
  
  local root = get_tree_root()
  if not root then
    log_action('move_next_preorder_same_type', 'no tree root found', current_info)
    return
  end

  -- Get all nodes of the same type in preorder
  local same_type_nodes = collect_nodes_by_type(root, target_type)
  
  if #same_type_nodes == 0 then
    log_action('move_next_preorder_same_type', 'no nodes of type found', current_info .. ' (type: ' .. target_type .. ')')
    return
  end
  
  -- Find the current node in the list and get the next one at a different position
  for i, same_node in ipairs(same_type_nodes) do
    if nodes_equal(same_node, node) then
      -- Look for the next node at a different position
      for j = i + 1, #same_type_nodes do
        local candidate = same_type_nodes[j]
        local candidate_row, candidate_col = candidate:start()
        
        if candidate_row ~= initial_row or candidate_col ~= initial_col then
          local target_info = get_node_info(candidate)
          log_action('move_next_preorder_same_type', 'found next same type node at different position', current_info .. ' -> ' .. target_info)
          set_cursor_to_node(candidate)
          
          -- Highlight reachable nodes
          local reachable = get_reachable_nodes('move_next_preorder_same_type')
          highlight_nodes_with_auto_clear(reachable, 'move_next_preorder_same_type')
          return
        end
      end
      
      log_action('move_next_preorder_same_type', 'no next same type node at different position', current_info .. ' (type: ' .. target_type .. ')')
      return
    end
  end
  
  log_action('move_next_preorder_same_type', 'current node not found in same type list', current_info .. ' (type: ' .. target_type .. ')')
end

function M.move_prev_preorder_same_type()
  local node = get_cursor_node()
  if not node then
    log_action('move_prev_preorder_same_type', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row, initial_col = initial_cursor[1] - 1, initial_cursor[2]
  local target_type = node:type()
  local current_info = get_node_info(node)
  
  local root = get_tree_root()
  if not root then
    log_action('move_prev_preorder_same_type', 'no tree root found', current_info)
    return
  end

  -- Get all nodes of the same type in preorder
  local same_type_nodes = collect_nodes_by_type(root, target_type)
  
  if #same_type_nodes == 0 then
    log_action('move_prev_preorder_same_type', 'no nodes of type found', current_info .. ' (type: ' .. target_type .. ')')
    return
  end
  
  -- Find the current node in the list and get the previous one at a different position
  for i, same_node in ipairs(same_type_nodes) do
    if nodes_equal(same_node, node) then
      -- Look for the previous node at a different position
      for j = i - 1, 1, -1 do
        local candidate = same_type_nodes[j]
        local candidate_row, candidate_col = candidate:start()
        
        if candidate_row ~= initial_row or candidate_col ~= initial_col then
          local target_info = get_node_info(candidate)
          log_action('move_prev_preorder_same_type', 'found previous same type node at different position', current_info .. ' -> ' .. target_info)
          set_cursor_to_node(candidate)
          
          -- Highlight reachable nodes
          local reachable = get_reachable_nodes('move_prev_preorder_same_type')
          highlight_nodes_with_auto_clear(reachable, 'move_prev_preorder_same_type')
          return
        end
      end
      
      log_action('move_prev_preorder_same_type', 'no previous same type node at different position', current_info .. ' (type: ' .. target_type .. ')')
      return
    end
  end
  
  log_action('move_prev_preorder_same_type', 'current node not found in same type list', current_info .. ' (type: ' .. target_type .. ')')
end

function M.move_next_preorder_different_line()
  local node = get_cursor_node()
  if not node then
    log_action('move_next_preorder_different_line', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row = initial_cursor[1] - 1
  local current_node = node
  local attempts = 0
  local max_attempts = 50 -- Higher limit since we're filtering by line
  
  local current_info = get_node_info(current_node)
  
  while attempts < max_attempts do
    local next_node = get_next_preorder(current_node)
    if not next_node then
      log_action('move_next_preorder_different_line', 'no next node in pre-order traversal', current_info)
      return
    end
    
    local next_start_row, _ = next_node:start()
    
    -- If the next node starts on a different line, move there
    if next_start_row ~= initial_row then
      local target_info = get_node_info(next_node)
      log_action('move_next_preorder_different_line', 'found node on different line after ' .. (attempts + 1) .. ' attempts', current_info .. ' -> ' .. target_info)
      set_cursor_to_node(next_node)
      
      -- Highlight reachable nodes
      local reachable = get_reachable_nodes('move_next_preorder_different_line')
      highlight_nodes_with_auto_clear(reachable, 'move_next_preorder_different_line')
      return
    end
    
    -- Continue to the next node
    current_node = next_node
    attempts = attempts + 1
  end
  
  log_action('move_next_preorder_different_line', 'reached max attempts without finding different line', current_info)
end

function M.move_prev_preorder_different_line()
  local node = get_cursor_node()
  if not node then
    log_action('move_prev_preorder_different_line', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row = initial_cursor[1] - 1
  local current_node = node
  local attempts = 0
  local max_attempts = 50 -- Higher limit since we're filtering by line
  
  local current_info = get_node_info(current_node)
  
  while attempts < max_attempts do
    local prev_node = get_prev_preorder(current_node)
    if not prev_node then
      log_action('move_prev_preorder_different_line', 'no previous node in pre-order traversal', current_info)
      return
    end
    
    local prev_start_row, _ = prev_node:start()
    
    -- If the previous node starts on a different line, move there
    if prev_start_row ~= initial_row then
      local target_info = get_node_info(prev_node)
      log_action('move_prev_preorder_different_line', 'found node on different line after ' .. (attempts + 1) .. ' attempts', current_info .. ' -> ' .. target_info)
      set_cursor_to_node(prev_node)
      
      -- Highlight reachable nodes
      local reachable = get_reachable_nodes('move_prev_preorder_different_line')
      highlight_nodes_with_auto_clear(reachable, 'move_prev_preorder_different_line')
      return
    end
    
    -- Continue to the previous node
    current_node = prev_node
    attempts = attempts + 1
  end
  
  log_action('move_prev_preorder_different_line', 'reached max attempts without finding different line', current_info)
end

function M.move_next_preorder_same_type_different_line()
  local node = get_cursor_node()
  if not node then
    log_action('move_next_preorder_same_type_different_line', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row = initial_cursor[1] - 1
  local target_type = node:type()
  local current_info = get_node_info(node)
  
  local root = get_tree_root()
  if not root then
    log_action('move_next_preorder_same_type_different_line', 'no tree root found', current_info)
    return
  end

  -- Get all nodes of the same type in preorder
  local same_type_nodes = collect_nodes_by_type(root, target_type)
  
  if #same_type_nodes == 0 then
    log_action('move_next_preorder_same_type_different_line', 'no nodes of type found', current_info .. ' (type: ' .. target_type .. ')')
    return
  end
  
  -- Find the current node in the list and get the next one on a different line
  for i, same_node in ipairs(same_type_nodes) do
    if nodes_equal(same_node, node) then
      -- Look for the next node on a different line
      for j = i + 1, #same_type_nodes do
        local candidate = same_type_nodes[j]
        local candidate_row, _ = candidate:start()
        
        if candidate_row ~= initial_row then
          local target_info = get_node_info(candidate)
          log_action('move_next_preorder_same_type_different_line', 'found next same type node on different line', current_info .. ' -> ' .. target_info)
          set_cursor_to_node(candidate)
          
          -- Highlight reachable nodes
          local reachable = get_reachable_nodes('move_next_preorder_same_type_different_line')
          highlight_nodes_with_auto_clear(reachable, 'move_next_preorder_same_type_different_line')
          return
        end
      end
      
      log_action('move_next_preorder_same_type_different_line', 'no next same type node on different line', current_info .. ' (type: ' .. target_type .. ')')
      return
    end
  end
  
  log_action('move_next_preorder_same_type_different_line', 'current node not found in same type list', current_info .. ' (type: ' .. target_type .. ')')
end

function M.move_prev_preorder_same_type_different_line()
  local node = get_cursor_node()
  if not node then
    log_action('move_prev_preorder_same_type_different_line', 'no node found at cursor', nil)
    return
  end

  local initial_cursor = vim.api.nvim_win_get_cursor(0)
  local initial_row = initial_cursor[1] - 1
  local target_type = node:type()
  local current_info = get_node_info(node)
  
  local root = get_tree_root()
  if not root then
    log_action('move_prev_preorder_same_type_different_line', 'no tree root found', current_info)
    return
  end

  -- Get all nodes of the same type in preorder
  local same_type_nodes = collect_nodes_by_type(root, target_type)
  
  if #same_type_nodes == 0 then
    log_action('move_prev_preorder_same_type_different_line', 'no nodes of type found', current_info .. ' (type: ' .. target_type .. ')')
    return
  end
  
  -- Find the current node in the list and get the previous one on a different line
  for i, same_node in ipairs(same_type_nodes) do
    if nodes_equal(same_node, node) then
      -- Look for the previous node on a different line
      for j = i - 1, 1, -1 do
        local candidate = same_type_nodes[j]
        local candidate_row, _ = candidate:start()
        
        if candidate_row ~= initial_row then
          local target_info = get_node_info(candidate)
          log_action('move_prev_preorder_same_type_different_line', 'found previous same type node on different line', current_info .. ' -> ' .. target_info)
          set_cursor_to_node(candidate)
          
          -- Highlight reachable nodes
          local reachable = get_reachable_nodes('move_prev_preorder_same_type_different_line')
          highlight_nodes_with_auto_clear(reachable, 'move_prev_preorder_same_type_different_line')
          return
        end
      end
      
      log_action('move_prev_preorder_same_type_different_line', 'no previous same type node on different line', current_info .. ' (type: ' .. target_type .. ')')
      return
    end
  end
  
  log_action('move_prev_preorder_same_type_different_line', 'current node not found in same type list', current_info .. ' (type: ' .. target_type .. ')')
end

return M
