local util = require 'lemur.util'

local function create(opts)
  opts = opts or {}
  local highlight_group = opts.highlight_group or 'LemurTargets'

  local state = {
    active = false,
    nodes = {},
    current_index = 1,
    picker_name = '',
    keymaps = {},
  }

  local picker = {}

  local function navigate_next()
    if not state.active or #state.nodes == 0 then
      return
    end

    state.current_index = state.current_index + 1
    if state.current_index > #state.nodes then
      state.current_index = 1
    end

    local target_node = state.nodes[state.current_index]
    util.set_cursor_to_node(target_node)

    util.log_action('navigate_next', 'moved to next node', string.format('index %d/%d', state.current_index, #state.nodes))
  end

  local function navigate_prev()
    if not state.active or #state.nodes == 0 then
      return
    end

    state.current_index = state.current_index - 1
    if state.current_index < 1 then
      state.current_index = #state.nodes
    end

    local target_node = state.nodes[state.current_index]
    util.set_cursor_to_node(target_node)

    util.log_action('navigate_prev', 'moved to previous node', string.format('index %d/%d', state.current_index, #state.nodes))
  end

  function picker.deactivate()
    if not state.active then
      return
    end

    util.log_action('deactivate', 'clearing sticky mode', state.picker_name)

    state.active = false
    state.nodes = {}
    state.current_index = 1
    state.picker_name = ''

    util.clear_highlights()
    vim.cmd 'echo ""'

    for _, keymap in ipairs(state.keymaps) do
      pcall(vim.keymap.del, 'n', keymap, { buffer = 0 })
    end
    state.keymaps = {}
  end

  function picker.activate(nodes, name)
    if #nodes == 0 then
      print('No nodes found for: ' .. name)
      return
    end

    picker.deactivate()

    state.active = true
    state.nodes = nodes
    state.picker_name = name

    -- Find nearest node to current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_node = util.get_cursor_node()

    -- Check if cursor is already exactly on a picked node
    local exact_match_index = nil
    if cursor_node then
      for i, node in ipairs(nodes) do
        local cursor_row, cursor_col = cursor_node:start()
        local node_row, node_col = node:start()
        if cursor_row == node_row and cursor_col == node_col then
          exact_match_index = i
          break
        end
      end
    end

    if exact_match_index then
      state.current_index = exact_match_index
      util.log_action('activate', 'cursor already on picked node', string.format('index %d/%d', exact_match_index, #nodes))
    else
      local nearest_index = util.find_nearest_node_index(nodes, cursor_pos)
      state.current_index = nearest_index

      local nearest_node = nodes[nearest_index]
      util.set_cursor_to_node(nearest_node)
      util.log_action('activate', 'jumped to nearest node', string.format('index %d/%d', nearest_index, #nodes))
    end

    util.highlight_nodes(nodes, highlight_group)

    vim.keymap.set('n', 'j', navigate_next, { buffer = 0, desc = 'Lemur: Next node in sticky mode' })
    vim.keymap.set('n', 'k', navigate_prev, { buffer = 0, desc = 'Lemur: Previous node in sticky mode' })
    vim.keymap.set('n', '<Esc>', picker.deactivate, { buffer = 0, desc = 'Lemur: Clear sticky mode' })

    state.keymaps = { 'j', 'k', '<Esc>' }

    util.log_action('activate', 'activated sticky mode', string.format('%s with %d nodes', name, #nodes))
    print(string.format('Lemur sticky mode: %s (%d nodes) - use j/k to navigate, <Esc> to exit', name, #nodes))
  end

  function picker.is_active()
    return state.active
  end

  return picker
end

return create
