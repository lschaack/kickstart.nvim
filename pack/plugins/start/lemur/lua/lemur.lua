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

-- Picker registry system
M.picker_registry = {}

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

-- LSP SymbolKind integration
local function collect_symbols_recursive(symbols, target_kind, result)
  for _, symbol in ipairs(symbols) do
    if symbol.kind == target_kind then
      table.insert(result, symbol)
    end
    if symbol.children then
      collect_symbols_recursive(symbol.children, target_kind, result)
    end
  end
end

local function get_lsp_symbols_by_kind(symbol_kind)
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    log_action('get_lsp_symbols_by_kind', 'no LSP clients available', tostring(symbol_kind))
    return {}
  end
  
  local params = { textDocument = vim.lsp.util.make_text_document_params() }
  local result = vim.lsp.buf_request_sync(0, 'textDocument/documentSymbol', params, 5000)
  
  if not result or vim.tbl_isempty(result) then
    log_action('get_lsp_symbols_by_kind', 'no LSP symbols returned', tostring(symbol_kind))
    return {}
  end
  
  local symbols = {}
  for _, res in pairs(result) do
    if res.result then
      collect_symbols_recursive(res.result, symbol_kind, symbols)
    end
  end
  
  log_action('get_lsp_symbols_by_kind', 'collected LSP symbols', string.format('%d symbols of kind %d', #symbols, symbol_kind))
  return symbols
end

local function find_node_at_position(pos)
  local row, col = pos.line, pos.character
  local parser = vim.treesitter.get_parser(0)
  if not parser then return nil end
  
  local tree = parser:parse()[1]
  if not tree then return nil end
  
  return tree:root():named_descendant_for_range(row, col, row, col)
end

local function symbols_to_nodes(symbols)
  local nodes = {}
  for _, symbol in ipairs(symbols) do
    local node = find_node_at_position(symbol.range.start)
    if node then
      table.insert(nodes, node)
    end
  end
  log_action('symbols_to_nodes', 'converted symbols to nodes', string.format('%d symbols -> %d nodes', #symbols, #nodes))
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
    pcall(vim.keymap.del, 'n', keymap, { buffer = 0 })
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

-- Picker registry and management functions
local function normalize_picker_config(config)
  if type(config) == 'string' then
    -- SymbolKind shorthand: 'Function' -> { kind = 'Function' }
    config = { kind = config }
  elseif type(config) == 'function' then
    -- Function shorthand: func -> { func = func }
    config = { func = config }
  end
  
  -- Ensure config is a table
  if type(config) ~= 'table' then
    error('Picker config must be a string, function, or table')
  end
  
  return config
end

local function create_picker_function(name, config)
  if config.type == 'builtin' and config.func then
    return config.func
  elseif config.kind then
    -- SymbolKind picker
    return function()
      local symbol_kind_map = {
        File = vim.lsp.protocol.SymbolKind.File,
        Module = vim.lsp.protocol.SymbolKind.Module,
        Namespace = vim.lsp.protocol.SymbolKind.Namespace,
        Package = vim.lsp.protocol.SymbolKind.Package,
        Class = vim.lsp.protocol.SymbolKind.Class,
        Method = vim.lsp.protocol.SymbolKind.Method,
        Property = vim.lsp.protocol.SymbolKind.Property,
        Field = vim.lsp.protocol.SymbolKind.Field,
        Constructor = vim.lsp.protocol.SymbolKind.Constructor,
        Enum = vim.lsp.protocol.SymbolKind.Enum,
        Interface = vim.lsp.protocol.SymbolKind.Interface,
        Function = vim.lsp.protocol.SymbolKind.Function,
        Variable = vim.lsp.protocol.SymbolKind.Variable,
        Constant = vim.lsp.protocol.SymbolKind.Constant,
        String = vim.lsp.protocol.SymbolKind.String,
        Number = vim.lsp.protocol.SymbolKind.Number,
        Boolean = vim.lsp.protocol.SymbolKind.Boolean,
        Array = vim.lsp.protocol.SymbolKind.Array,
        Object = vim.lsp.protocol.SymbolKind.Object,
        Key = vim.lsp.protocol.SymbolKind.Key,
        Null = vim.lsp.protocol.SymbolKind.Null,
        EnumMember = vim.lsp.protocol.SymbolKind.EnumMember,
        Struct = vim.lsp.protocol.SymbolKind.Struct,
        Event = vim.lsp.protocol.SymbolKind.Event,
        Operator = vim.lsp.protocol.SymbolKind.Operator,
        TypeParameter = vim.lsp.protocol.SymbolKind.TypeParameter,
      }
      
      local symbol_kind = symbol_kind_map[config.kind]
      if not symbol_kind then
        print('Unknown SymbolKind: ' .. config.kind)
        return
      end
      
      local symbols = get_lsp_symbols_by_kind(symbol_kind)
      local nodes = symbols_to_nodes(symbols)
      
      if #nodes == 0 then
        print('No ' .. config.kind .. ' symbols found')
        return
      end
      
      activate_sticky_mode(nodes, config.name or (config.kind .. ' symbols'))
    end
  elseif config.func then
    -- Custom function picker
    return function()
      local nodes = config.func()
      if not nodes or #nodes == 0 then
        print('No nodes found for picker: ' .. (config.name or name))
        return
      end
      activate_sticky_mode(nodes, config.name or name)
    end
  else
    error('Picker config must have either "kind" or "func" field')
  end
end

function M.register_picker(name, config)
  config = normalize_picker_config(config)
  
  -- Set defaults
  config.name = config.name or name
  config.type = config.type or (config.kind and 'symbol' or 'function')
  
  M.picker_registry[name] = config
  
  -- Auto-setup keymap if provided
  if config.keymap then
    local picker_func = create_picker_function(name, config)
    vim.keymap.set('n', config.keymap, 
      M.toggle_sticky_mode(picker_func, config.name), 
      { desc = 'Lemur: ' .. config.name })
    log_action('register_picker', 'registered picker with keymap', string.format('%s -> %s', name, config.keymap))
  else
    log_action('register_picker', 'registered picker', name)
  end
end

function M.get_picker(name)
  local config = M.picker_registry[name]
  if not config then
    return nil
  end
  return create_picker_function(name, config)
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

  -- Register built-in pickers
  M.register_picker('same_type', { 
    func = same_type_picker, 
    type = 'builtin',
    keymap = M.config.keymaps.same_type_picker,
    name = 'Same Type'
  })

  -- Process user-defined pickers
  if opts.pickers then
    for name, config in pairs(opts.pickers) do
      if config == false then
        -- Disable picker by removing it from registry
        M.picker_registry[name] = nil
        log_action('setup', 'disabled picker', name)
      else
        M.register_picker(name, config)
      end
    end
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