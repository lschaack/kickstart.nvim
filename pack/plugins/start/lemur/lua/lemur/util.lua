local M = {}

M.debug = false
M.logs = {}
M.highlight_ns = nil

function M.log_action(action, reason, info)
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

function M.get_cursor_node(bufnr)
  bufnr = bufnr or 0
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  return tree:root():named_descendant_for_range(row, col, row, col)
end

function M.get_tree_root(bufnr)
  bufnr = bufnr or 0
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  return tree:root()
end

function M.find_nearest_node_index(nodes, cursor_pos)
  if #nodes == 0 then
    return 1
  end
  if not cursor_pos then
    return 1
  end

  local cursor_row, cursor_col = cursor_pos[1] - 1, cursor_pos[2]
  local nearest_index = 1
  local min_distance = math.huge

  for i, node in ipairs(nodes) do
    local node_row, node_col = node:start()
    local distance = math.abs(cursor_row - node_row) + math.abs(cursor_col - node_col)

    if distance < min_distance then
      min_distance = distance
      nearest_index = i
    end
  end

  return nearest_index
end

function M.set_cursor_to_node(node)
  if not node then
    return
  end

  local start_row, start_col = node:start()
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
end

function M.clear_highlights(bufnr)
  bufnr = bufnr or 0
  if M.highlight_ns then
    vim.api.nvim_buf_clear_namespace(bufnr, M.highlight_ns, 0, -1)
  end
end

function M.highlight_nodes(nodes, highlight_group, bufnr)
  bufnr = bufnr or 0
  if not M.highlight_ns or not nodes then
    return
  end

  M.clear_highlights(bufnr)

  for _, node in ipairs(nodes) do
    if node then
      local start_row, start_col = node:start()
      local _, end_col = node:end_()
      vim.api.nvim_buf_add_highlight(bufnr, M.highlight_ns, highlight_group, start_row, start_col, end_col)
    end
  end
end

function M.init_highlight_ns()
  if not M.highlight_ns then
    M.highlight_ns = vim.api.nvim_create_namespace 'lemur_highlights'
  end
  return M.highlight_ns
end

function M.sort_nodes_by_position(nodes)
  table.sort(nodes, function(a, b)
    local a_row, a_col = a:start()
    local b_row, b_col = b:start()
    if a_row == b_row then
      return a_col < b_col
    end
    return a_row < b_row
  end)
  return nodes
end

function M.deduplicate_nodes(nodes)
  local seen = {}
  local result = {}
  for _, node in ipairs(nodes) do
    local sr, sc = node:start()
    local er, ec = node:end_()
    local key = string.format('%d:%d:%d:%d', sr, sc, er, ec)
    if not seen[key] then
      seen[key] = true
      table.insert(result, node)
    end
  end
  return result
end

return M
