local M = {}

M.debug = false
M.logs = {}
M.sticky_state = {
  active = false,
  nodes = {},
  current_index = 1,
  picker_name = '',
  keymaps = {}
}
M.highlight_ns = nil

M.config = {
  keymaps = {
    same_type_picker = '<leader>ls',
  },
  highlight = {
    highlight_group = 'LemurTargets',
  },
}

local function log_action(action, reason, info)
  if not M.debug then
    return
  end

  local timestamp = os.date '%H:%M:%S'
  local entry = string.format('[%s] %s: %s (%s)', timestamp, action, reason, info or 'unknown')

  table.insert(M.logs, entry)

  if #M.logs > 100 then
    table.remove(M.logs, 1)
  end

  print(entry)
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

local function clear_highlights()
  if M.highlight_ns then
    vim.api.nvim_buf_clear_namespace(0, M.highlight_ns, 0, -1)
  end
end

local function highlight_nodes(nodes)
  if not M.highlight_ns or not nodes then
    return
  end

  clear_highlights()
  
  for _, node in ipairs(nodes) do
    if node then
      local start_row, start_col = node:start()
      local end_row, end_col = node:end_()
      vim.api.nvim_buf_add_highlight(0, M.highlight_ns, M.config.highlight.highlight_group, start_row, start_col, end_col)
    end
  end
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

  return tree:root():named_descendant_for_range(row, col, row, col)
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

local function set_cursor_to_node(node)
  if not node then
    return
  end

  local start_row, start_col = node:start()
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
end

local function clear_sticky_mode()
  if not M.sticky_state.active then
    return
  end

  log_action('clear_sticky_mode', 'clearing sticky mode', M.sticky_state.picker_name)
  
  M.sticky_state.active = false
  M.sticky_state.nodes = {}
  M.sticky_state.current_index = 1
  M.sticky_state.picker_name = ''
  
  clear_highlights()
  
  -- Remove temporary keymaps
  for _, keymap in ipairs(M.sticky_state.keymaps) do
    vim.keymap.del('n', keymap)
  end
  M.sticky_state.keymaps = {}
end

local function navigate_next()
  if not M.sticky_state.active or #M.sticky_state.nodes == 0 then
    return
  end

  M.sticky_state.current_index = M.sticky_state.current_index + 1
  if M.sticky_state.current_index > #M.sticky_state.nodes then
    M.sticky_state.current_index = 1
  end

  local target_node = M.sticky_state.nodes[M.sticky_state.current_index]
  set_cursor_to_node(target_node)
  
  log_action('navigate_next', 'moved to next node', string.format('index %d/%d', M.sticky_state.current_index, #M.sticky_state.nodes))
end

local function navigate_prev()
  if not M.sticky_state.active or #M.sticky_state.nodes == 0 then
    return
  end

  M.sticky_state.current_index = M.sticky_state.current_index - 1
  if M.sticky_state.current_index < 1 then
    M.sticky_state.current_index = #M.sticky_state.nodes
  end

  local target_node = M.sticky_state.nodes[M.sticky_state.current_index]
  set_cursor_to_node(target_node)
  
  log_action('navigate_prev', 'moved to previous node', string.format('index %d/%d', M.sticky_state.current_index, #M.sticky_state.nodes))
end

local function activate_sticky_mode(nodes, picker_name)
  if #nodes == 0 then
    print('No nodes found for picker: ' .. picker_name)
    return
  end

  clear_sticky_mode()
  
  M.sticky_state.active = true
  M.sticky_state.nodes = nodes
  M.sticky_state.picker_name = picker_name
  
  -- Find current cursor position in the nodes to set initial index
  local cursor_node = get_cursor_node()
  M.sticky_state.current_index = 1
  
  if cursor_node then
    for i, node in ipairs(nodes) do
      local cursor_row, cursor_col = cursor_node:start()
      local node_row, node_col = node:start()
      if cursor_row == node_row and cursor_col == node_col then
        M.sticky_state.current_index = i
        break
      end
    end
  end

  highlight_nodes(nodes)
  
  -- Set up temporary keymaps for j/k navigation and escape
  vim.keymap.set('n', 'j', navigate_next, { buffer = 0, desc = 'Lemur: Next node in sticky mode' })
  vim.keymap.set('n', 'k', navigate_prev, { buffer = 0, desc = 'Lemur: Previous node in sticky mode' })
  vim.keymap.set('n', '<Esc>', clear_sticky_mode, { buffer = 0, desc = 'Lemur: Clear sticky mode' })
  
  table.insert(M.sticky_state.keymaps, 'j')
  table.insert(M.sticky_state.keymaps, 'k')
  table.insert(M.sticky_state.keymaps, '<Esc>')
  
  log_action('activate_sticky_mode', 'activated sticky mode', string.format('%s with %d nodes', picker_name, #nodes))
  print(string.format('Lemur sticky mode: %s (%d nodes) - use j/k to navigate, <Esc> to exit', picker_name, #nodes))
end

-- Node picker functions
local function same_type_picker()
  local current_node = get_cursor_node()
  if not current_node then
    print 'No node found at cursor'
    return
  end

  local root = get_tree_root()
  if not root then
    print 'No tree root found'
    return
  end

  local target_type = current_node:type()
  local nodes = collect_nodes_by_type(root, target_type)
  
  activate_sticky_mode(nodes, 'same_type (' .. target_type .. ')')
end

function M.toggle_sticky_mode(picker_func, picker_name)
  return function()
    if M.sticky_state.active then
      clear_sticky_mode()
    else
      picker_func()
    end
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
  M.highlight_ns = vim.api.nvim_create_namespace 'lemur_highlights'

  -- Set up highlight group
  vim.api.nvim_set_hl(0, M.config.highlight.highlight_group, {
    bg = '#3e4451',
    fg = '#abb2bf',
    default = true,
  })

  -- Set up default keymaps
  if M.config.keymaps.same_type_picker ~= nil then
    vim.keymap.set('n', M.config.keymaps.same_type_picker, M.toggle_sticky_mode(same_type_picker, 'same_type'), { desc = 'Lemur: Toggle same type sticky mode' })
  end

  -- Set up commands
  vim.api.nvim_create_user_command('LemurToggleDebug', M.toggle_debug, { desc = 'Toggle lemur debug mode' })
  vim.api.nvim_create_user_command('LemurLogs', M.show_logs, { desc = 'Show lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearLogs', M.clear_logs, { desc = 'Clear lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearSticky', clear_sticky_mode, { desc = 'Clear lemur sticky mode' })

  if opts.debug then
    M.toggle_debug()
  end
end

-- Export picker functions for custom configurations
M.pickers = {
  same_type = same_type_picker,
}

return M