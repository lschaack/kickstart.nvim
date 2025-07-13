local M = {}

M.debug = false
M.logs = {}
M.last_node = nil

M.config = {
  keymaps = {
    move_down = '<M-j>',
    move_up = '<M-k>',
    move_right = '<M-l>',
    move_left = '<M-h>',
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

function M.setup(opts)
  opts = opts or {}

  -- Merge user config with defaults
  if opts.keymaps then
    M.config.keymaps = vim.tbl_deep_extend('force', M.config.keymaps, opts.keymaps)
  end

  -- Set up keymaps
  vim.keymap.set('n', M.config.keymaps.move_down, M.move_down, { desc = 'Lemur: Move to next sibling or parent' })
  vim.keymap.set('n', M.config.keymaps.move_up, M.move_up, { desc = 'Lemur: Move to previous sibling or parent' })
  vim.keymap.set('n', M.config.keymaps.move_right, M.move_right, { desc = 'Lemur: Move to child or next sibling up tree' })
  vim.keymap.set('n', M.config.keymaps.move_left, M.move_left, { desc = 'Lemur: Move to parent node' })

  -- Set up commands
  vim.api.nvim_create_user_command('LemurToggleDebug', M.toggle_debug, { desc = 'Toggle lemur debug mode' })
  vim.api.nvim_create_user_command('LemurLogs', M.show_logs, { desc = 'Show lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearLogs', M.clear_logs, { desc = 'Clear lemur debug logs' })

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

function M.move_down()
  local node = get_cursor_node()
  if not node then
    log_action('move_down', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  local next_sibling = get_next_sibling(node)
  if next_sibling then
    local target_info = get_node_info(next_sibling)
    log_action('move_down', 'found next sibling', current_info .. ' -> ' .. target_info)
    set_cursor_to_node(next_sibling)
  else
    if move_to_parent_with_fallback(node) then
      local new_node = get_cursor_node()
      local target_info = get_node_info(new_node)
      log_action('move_down', 'no next sibling, moved to parent/fallback', current_info .. ' -> ' .. target_info)
    else
      log_action('move_down', 'no next sibling and no viable parent move', current_info)
    end
  end
end

function M.move_up()
  local node = get_cursor_node()
  if not node then
    log_action('move_up', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  local prev_sibling = get_prev_sibling(node)
  if prev_sibling then
    local target_info = get_node_info(prev_sibling)
    log_action('move_up', 'found previous sibling', current_info .. ' -> ' .. target_info)
    set_cursor_to_node(prev_sibling)
  else
    if move_to_parent_with_fallback(node) then
      local new_node = get_cursor_node()
      local target_info = get_node_info(new_node)
      log_action('move_up', 'no previous sibling, moved to parent/fallback', current_info .. ' -> ' .. target_info)
    else
      log_action('move_up', 'no previous sibling and no viable parent move', current_info)
    end
  end
end

function M.move_right()
  local node = get_cursor_node()
  if not node then
    log_action('move_right', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  local first_child = get_first_child(node)
  if first_child then
    local target_info = get_node_info(first_child)
    log_action('move_right', 'found first child', current_info .. ' -> ' .. target_info)
    set_cursor_to_node(first_child)
  else
    local next_sibling = find_next_sibling_up_tree(node)
    if next_sibling then
      local target_info = get_node_info(next_sibling)
      log_action('move_right', 'no child, found next sibling up tree', current_info .. ' -> ' .. target_info)
      set_cursor_to_node(next_sibling)
    else
      log_action('move_right', 'no child and no next sibling up tree', current_info)
    end
  end
end

function M.move_left()
  local node = get_cursor_node()
  if not node then
    log_action('move_left', 'no node found at cursor', nil)
    return
  end

  local current_info = get_node_info(node)
  if move_to_parent_with_fallback(node) then
    local new_node = get_cursor_node()
    local target_info = get_node_info(new_node)
    log_action('move_left', 'moved to parent/fallback', current_info .. ' -> ' .. target_info)
  else
    log_action('move_left', 'no viable parent move', current_info)
  end
end

return M
