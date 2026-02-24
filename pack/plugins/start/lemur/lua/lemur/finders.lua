local util = require 'lemur.util'

local M = {}

-- Helper: collect all nodes of a given type from a tree root
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

-- Helper: LSP symbol collection
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

local function find_node_at_position(bufnr, pos)
  local row, col = pos.line, pos.character
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

local function symbols_to_nodes(symbols, bufnr)
  local nodes = {}
  for _, symbol in ipairs(symbols) do
    local node = find_node_at_position(bufnr, symbol.range.start)
    if node then
      table.insert(nodes, node)
    end
  end
  util.log_action('symbols_to_nodes', 'converted symbols to nodes', string.format('%d symbols -> %d nodes', #symbols, #nodes))
  return nodes
end

local symbol_kind_map = {
  File = 1,
  Module = 2,
  Namespace = 3,
  Package = 4,
  Class = 5,
  Method = 6,
  Property = 7,
  Field = 8,
  Constructor = 9,
  Enum = 10,
  Interface = 11,
  Function = 12,
  Variable = 13,
  Constant = 14,
  String = 15,
  Number = 16,
  Boolean = 17,
  Array = 18,
  Object = 19,
  Key = 20,
  Null = 21,
  EnumMember = 22,
  Struct = 23,
  Event = 24,
  Operator = 25,
  TypeParameter = 26,
}

--- Create a finder from a tree-sitter query file.
--- Uses community-maintained .scm files (context.scm, locals.scm, textobjects.scm, highlights.scm).
--- @param query_group string The query group name (e.g. 'context', 'locals', 'textobjects', 'highlights')
--- @param capture_name string The capture name to extract (e.g. 'context', 'function.outer')
--- @return function(bufnr?): node[]
function M.query(query_group, capture_name)
  return function(bufnr)
    bufnr = bufnr or 0
    local ft = vim.bo[bufnr].filetype
    local lang = vim.treesitter.language.get_lang(ft) or ft

    local ok, query = pcall(vim.treesitter.query.get, lang, query_group)
    if not ok or not query then
      util.log_action('finders.query', 'no query found', string.format('%s/%s for lang %s', query_group, capture_name, lang))
      return {}
    end

    local parser = vim.treesitter.get_parser(bufnr, lang)
    if not parser then
      return {}
    end

    local tree = parser:parse()[1]
    if not tree then
      return {}
    end

    local root = tree:root()
    local nodes = {}
    local target = capture_name:gsub('%.', '%%.') -- escape dots for pattern matching

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
      local name = query.captures[id]
      if name == capture_name or name:match('^' .. target .. '$') then
        table.insert(nodes, node)
      end
    end

    nodes = util.deduplicate_nodes(nodes)
    nodes = util.sort_nodes_by_position(nodes)

    util.log_action('finders.query', 'collected nodes', string.format('%s/@%s -> %d nodes', query_group, capture_name, #nodes))
    return nodes
  end
end

--- Create a finder from LSP document symbols.
--- @param kind_name string The SymbolKind name (e.g. 'Function', 'Class', 'Variable')
--- @return function(bufnr?): node[]
function M.lsp_symbols(kind_name)
  return function(bufnr)
    bufnr = bufnr or 0
    local symbol_kind = symbol_kind_map[kind_name]
    if not symbol_kind then
      util.log_action('finders.lsp_symbols', 'unknown SymbolKind', kind_name)
      return {}
    end

    local clients = vim.lsp.get_clients { bufnr = bufnr }
    if #clients == 0 then
      util.log_action('finders.lsp_symbols', 'no LSP clients available', kind_name)
      return {}
    end

    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    local result = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, 5000)

    if not result or vim.tbl_isempty(result) then
      util.log_action('finders.lsp_symbols', 'no LSP symbols returned', kind_name)
      return {}
    end

    local symbols = {}
    for _, res in pairs(result) do
      if res.result then
        collect_symbols_recursive(res.result, symbol_kind, symbols)
      end
    end

    local nodes = symbols_to_nodes(symbols, bufnr)
    nodes = util.sort_nodes_by_position(nodes)

    util.log_action('finders.lsp_symbols', 'collected symbols', string.format('%d %s symbols -> %d nodes', #symbols, kind_name, #nodes))
    return nodes
  end
end

--- Create a finder for a specific node type.
--- @param type_string string The tree-sitter node type (e.g. 'function_declaration')
--- @return function(bufnr?): node[]
function M.node_type(type_string)
  return function(bufnr)
    bufnr = bufnr or 0
    local root = util.get_tree_root(bufnr)
    if not root then
      return {}
    end

    local nodes = collect_nodes_by_type(root, type_string)
    nodes = util.sort_nodes_by_position(nodes)

    util.log_action('finders.node_type', 'collected nodes', string.format('type=%s -> %d nodes', type_string, #nodes))
    return nodes
  end
end

--- Create a dynamic finder that uses the node type under the cursor.
--- Equivalent to the old same_type_picker behavior.
--- @return function(bufnr?): node[]
function M.cursor_type()
  return function(bufnr)
    bufnr = bufnr or 0
    local current_node = util.get_cursor_node(bufnr)
    if not current_node then
      return {}
    end

    local target_type = current_node:type()
    local root = util.get_tree_root(bufnr)
    if not root then
      return {}
    end

    local nodes = collect_nodes_by_type(root, target_type)
    nodes = util.sort_nodes_by_position(nodes)

    util.log_action('finders.cursor_type', 'collected nodes', string.format('type=%s -> %d nodes', target_type, #nodes))
    return nodes
  end
end

--- Wrap a custom function as a finder.
--- @param fn function(bufnr): node[]
--- @return function(bufnr?): node[]
function M.custom(fn)
  return function(bufnr)
    bufnr = bufnr or 0
    local nodes = fn(bufnr) or {}
    nodes = util.sort_nodes_by_position(nodes)
    return nodes
  end
end

--- Combine results from two finders (union).
--- @param finder_a function
--- @param finder_b function
--- @return function(bufnr?): node[]
function M.union(finder_a, finder_b)
  return function(bufnr)
    bufnr = bufnr or 0
    local nodes_a = finder_a(bufnr)
    local nodes_b = finder_b(bufnr)

    local combined = {}
    for _, n in ipairs(nodes_a) do
      table.insert(combined, n)
    end
    for _, n in ipairs(nodes_b) do
      table.insert(combined, n)
    end

    combined = util.deduplicate_nodes(combined)
    combined = util.sort_nodes_by_position(combined)
    return combined
  end
end

--- Filter nodes from a finder using a predicate.
--- @param finder function
--- @param predicate_fn function(node, bufnr): boolean
--- @return function(bufnr?): node[]
function M.filter(finder, predicate_fn)
  return function(bufnr)
    bufnr = bufnr or 0
    local nodes = finder(bufnr)
    local result = {}

    for _, node in ipairs(nodes) do
      if predicate_fn(node, bufnr) then
        table.insert(result, node)
      end
    end

    return result
  end
end

--- Intersect two finders (nodes present in both).
--- @param finder_a function
--- @param finder_b function
--- @return function(bufnr?): node[]
function M.intersect(finder_a, finder_b)
  return function(bufnr)
    bufnr = bufnr or 0
    local nodes_a = finder_a(bufnr)
    local nodes_b = finder_b(bufnr)

    -- Build set from finder_b
    local set_b = {}
    for _, node in ipairs(nodes_b) do
      local sr, sc = node:start()
      local er, ec = node:end_()
      set_b[string.format('%d:%d:%d:%d', sr, sc, er, ec)] = true
    end

    local result = {}
    for _, node in ipairs(nodes_a) do
      local sr, sc = node:start()
      local er, ec = node:end_()
      if set_b[string.format('%d:%d:%d:%d', sr, sc, er, ec)] then
        table.insert(result, node)
      end
    end

    return result
  end
end

return M
