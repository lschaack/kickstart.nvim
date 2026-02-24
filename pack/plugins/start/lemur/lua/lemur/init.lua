local util = require 'lemur.util'
local finders_mod = require 'lemur.finders'
local pickers_mod = require 'lemur.pickers'

local M = {}

M.config = {
  debug = false,
  highlight = {
    highlight_group = 'LemurTargets',
  },
  picker = nil, -- default picker instance, created in setup
  finders = {},
}

-- Registry of name -> { finder, picker, name }
M._registry = {}

-- Default picker instance (set during setup)
M._default_picker = nil

--- Register a finder with optional picker and keymap.
--- @param name string
--- @param config table { finder, keymap?, name?, picker? }
function M.register(name, config)
  local picker = config.picker or M._default_picker
  local display_name = config.name or name

  M._registry[name] = {
    finder = config.finder,
    picker = picker,
    name = display_name,
  }

  if config.keymap then
    vim.keymap.set('n', config.keymap, function()
      M.activate(name)
    end, { desc = 'Lemur: ' .. display_name })
    util.log_action('register', 'registered with keymap', string.format('%s -> %s', name, config.keymap))
  else
    util.log_action('register', 'registered', name)
  end
end

--- Activate a registered finder by name.
--- @param name string
function M.activate(name)
  local entry = M._registry[name]
  if not entry then
    print('Lemur: unknown finder "' .. name .. '"')
    return
  end

  local picker = entry.picker
  if not picker then
    print('Lemur: no picker available for "' .. name .. '"')
    return
  end

  -- If this picker is already active, toggle it off
  if picker.is_active() then
    picker.deactivate()
    return
  end

  local nodes = entry.finder(0)
  if not nodes or #nodes == 0 then
    print('No nodes found for: ' .. entry.name)
    return
  end

  picker.activate(nodes, entry.name)
end

--- Backward-compatible conversion of old `pickers` config to new `finders` config.
local function convert_legacy_pickers(pickers_config)
  local result = {}

  for name, config in pairs(pickers_config) do
    if config == false then
      -- Skip disabled pickers
    elseif type(config) == 'string' then
      -- SymbolKind shorthand: 'Function'
      result[name] = {
        finder = finders_mod.lsp_symbols(config),
        name = config .. ' symbols',
      }
    elseif type(config) == 'function' then
      -- Function shorthand
      result[name] = {
        finder = finders_mod.custom(function(bufnr)
          return config()
        end),
        name = name,
      }
    elseif type(config) == 'table' then
      if config.kind then
        -- SymbolKind picker
        result[name] = {
          finder = finders_mod.lsp_symbols(config.kind),
          keymap = config.keymap,
          name = config.name or (config.kind .. ' symbols'),
          picker = config.picker,
        }
      elseif config.func then
        -- Custom function picker
        result[name] = {
          finder = finders_mod.custom(function(bufnr)
            return config.func()
          end),
          keymap = config.keymap,
          name = config.name or name,
          picker = config.picker,
        }
      end
    end
  end

  return result
end

function M.setup(opts)
  opts = opts or {}

  -- Merge highlight config
  if opts.highlight then
    M.config.highlight = vim.tbl_deep_extend('force', M.config.highlight, opts.highlight)
  end

  -- Initialize highlight namespace
  util.init_highlight_ns()

  -- Set up highlight group
  vim.api.nvim_set_hl(0, M.config.highlight.highlight_group, {
    bg = '#3e4451',
    fg = '#abb2bf',
    default = true,
  })

  -- Create or use provided default picker
  M._default_picker = opts.picker or pickers_mod.sticky { highlight_group = M.config.highlight.highlight_group }
  M.config.picker = M._default_picker

  -- Register built-in same_type finder
  local same_type_keymap = '<leader>ls'
  if opts.keymaps and opts.keymaps.same_type_picker then
    same_type_keymap = opts.keymaps.same_type_picker
  end

  M.register('same_type', {
    finder = finders_mod.cursor_type(),
    keymap = same_type_keymap,
    name = 'Same Type',
  })

  -- Process finders config (new API)
  if opts.finders then
    for name, config in pairs(opts.finders) do
      if config == false then
        M._registry[name] = nil
      else
        M.register(name, config)
      end
    end
  end

  -- Process legacy pickers config (backward compat)
  if opts.pickers then
    local converted = convert_legacy_pickers(opts.pickers)
    for name, config in pairs(converted) do
      M.register(name, config)
    end
  end

  -- Set up commands
  vim.api.nvim_create_user_command('LemurToggleDebug', util.toggle_debug, { desc = 'Toggle lemur debug mode' })
  vim.api.nvim_create_user_command('LemurLogs', util.show_logs, { desc = 'Show lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearLogs', util.clear_logs, { desc = 'Clear lemur debug logs' })
  vim.api.nvim_create_user_command('LemurClearSticky', function()
    if M._default_picker and M._default_picker.is_active() then
      M._default_picker.deactivate()
    end
  end, { desc = 'Clear lemur sticky mode' })

  if opts.debug then
    util.toggle_debug()
  end
end

-- Re-export submodules for convenience
M.finders = finders_mod
M.pickers = pickers_mod
M.util = util

-- Re-export debug functions for command compatibility
M.toggle_debug = util.toggle_debug
M.show_logs = util.show_logs
M.clear_logs = util.clear_logs

return M
