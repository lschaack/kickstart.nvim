vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

-- require 'custom.plugins.ts-actions'
require 'custom.plugins.blink'

vim.keymap.set('n', '<leader><tab>', '<c-^><cr>', { desc = '[B]ack' })
vim.keymap.set('n', '<M-f>', 'f r<enter>^', { desc = 'Break on next space' })
vim.keymap.set('c', '<M-r>', 's/<C-r>0//g<Left><Left>', { desc = '[R]eplace the contents of the default register' })
vim.keymap.set({ 'n', 'v' }, '<M-r>', ':s/<C-r>0//g<Left><Left>', { desc = '[R]eplace the contents of the default register' })
vim.keymap.set('n', '<leader>jk', "oconsole.log('<C-o>p', <C-o>p)<esc>", { desc = 'Paste last yanked text [j]s style' })
-- vim.keymap.set(
--   'n',
--   '<M-j>',
--   '<cmd>cnext<CR>',
--   { desc = 'Go to next quickfix item' }
-- )
-- vim.keymap.set(
--   'n',
--   '<M-k>',
--   '<cmd>cprev<CR>',
--   { desc = 'Go to previous quickfix item' }
-- )

vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('custom-term-open', { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})
vim.keymap.set('n', '<space>st', function()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd 'J'
  vim.api.nvim_win_set_height(0, 15)
end)
vim.keymap.set('n', '<M-c>', 'vBgUE', { desc = '[C]apitalize last typed word' })
vim.keymap.set('i', '<M-c>', '<esc>vBgUEa', { desc = '[C]apitalize last typed word' })

vim.api.nvim_create_augroup('typescript_makeprg', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = 'typescript_makeprg',
  pattern = { 'typescript', 'typescriptreact' },
  callback = function()
    vim.opt_local.makeprg = 'tsc --noEmit'
    vim.opt_local.errorformat = '%+A %#%f %#(%l\\,%c): %m,%C%m'
  end,
})

return {
  'mg979/vim-visual-multi',
  {
    'mikesmithgh/kitty-scrollback.nvim',
    enabled = true,
    lazy = true,
    cmd = { 'KittyScrollbackGenerateKittens', 'KittyScrollbackCheckHealth', 'KittyScrollbackGenerateCommandLineEditing' },
    event = { 'User KittyScrollbackLaunch' },
    -- version = '*', -- latest stable version, may have breaking changes if major version changed
    -- version = '^6.0.0', -- pin major version, include fixes and features that do not have breaking changes
    config = function()
      require('kitty-scrollback').setup()
    end,
  },
  {
    'ckolkey/ts-node-action',
    dependencies = { 'nvim-treesitter' },
    opts = {},
    config = function()
      vim.keymap.set({ 'n' }, '<leader>cf', require('ts-node-action').node_action, { desc = 'Trigger Node Action' })
      require('ts-node-action').setup {
        tsx = require 'ts-node-action.filetypes.javascript',
      }
    end,
  },
  {
    dir = vim.fn.stdpath 'config' .. '/pack/plugins/start/github-url',
    name = 'github-url',
    lazy = false,
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>gu', "<cmd>lua require('github_url').copy_github_url()<CR>", { noremap = true, silent = true })
    end,
  },
  {
    dir = vim.fn.stdpath 'config' .. '/pack/plugins/start/claude-path',
    name = 'claude-path',
    lazy = false,
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>cp', "<cmd>lua require('claude_path').copy_claude_path()<CR>", { noremap = true, silent = true })
    end,
  },
  {
    dir = vim.fn.stdpath 'config' .. '/pack/plugins/start/lemur',
    name = 'lemur',
    lazy = false,
    opts = {
      debug = false,
      highlight = {
        highlight_group = 'LemurTargets',
      },
      pickers = {
        -- SymbolKind pickers with custom keymaps
        functions = { kind = 'Function', keymap = '<leader>lf', name = 'Functions' },
        variables = { kind = 'Variable', keymap = '<leader>lv', name = 'Variables' },
        classes = { kind = 'Class', keymap = '<leader>lc', name = 'Classes' },
        methods = { kind = 'Method', keymap = '<leader>lm', name = 'Methods' },

        -- Custom function picker for TODO comments
        todos = {
          func = function()
            local nodes = {}
            local parser = vim.treesitter.get_parser(0)
            if not parser then
              return nodes
            end

            local tree = parser:parse()[1]
            if not tree then
              return nodes
            end

            local function traverse(node)
              if node:type() == 'comment' then
                local text = vim.treesitter.get_node_text(node, 0)
                if text and (text:match 'TODO' or text:match 'FIXME' or text:match 'NOTE') then
                  table.insert(nodes, node)
                end
              end

              for child in node:iter_children() do
                traverse(child)
              end
            end

            traverse(tree:root())
            return nodes
          end,
          keymap = '<leader>lt',
          name = 'TODO Comments',
        },
      },
    },
  },
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup {
        suggestion = {
          enabled = true,
          auto_trigger = false,
          keymap = {
            accept_word = false,
            accept_line = false,
            accept = '«', -- option+\
            next = '‘', -- option+]
            prev = '“', -- option+[
          },
        },
      }
    end,
  },
  {
    'folke/trouble.nvim',
    opts = {}, -- for default options, refer to the configuration section for custom setup.
    cmd = 'Trouble',
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<cr>',
        desc = 'Diagnostics (Trouble)',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Buffer Diagnostics (Trouble)',
      },
      {
        '<leader>cs',
        '<cmd>Trouble symbols toggle focus=false<cr>',
        desc = 'Symbols (Trouble)',
      },
      {
        '<leader>cl',
        '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
        desc = 'LSP Definitions / references / ... (Trouble)',
      },
      {
        '<leader>xL',
        '<cmd>Trouble loclist toggle<cr>',
        desc = 'Location List (Trouble)',
      },
      {
        '<leader>xQ',
        '<cmd>Trouble qflist toggle<cr>',
        desc = 'Quickfix List (Trouble)',
      },
    },
  },
}
