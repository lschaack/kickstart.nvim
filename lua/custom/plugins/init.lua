vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

require 'custom.plugins.ts-actions'
require 'custom.plugins.blink'

vim.keymap.set('n', '<leader><tab>', '<c-^><cr>', { desc = '[B]ack' })
vim.keymap.set(
  'n',
  'ƒ', -- option + f
  'f r<enter>^',
  { desc = 'Break on next space' }
)
vim.keymap.set(
  'c',
  '®', -- option + r
  's/<C-r>0//g<Left><Left>',
  { desc = '[R]eplace the contents of the default register' }
)
vim.keymap.set(
  'n',
  '∆', -- option + j
  '<cmd>cnext<CR>',
  { desc = 'Go to next quickfix item' }
)
vim.keymap.set(
  'n',
  '˚', -- option + k
  '<cmd>cprev<CR>',
  { desc = 'Go to previous quickfix item' }
)

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

return {
  'mg979/vim-visual-multi',
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      settings = {
        tsserver_file_preferences = {
          importModuleSpecifier = 'non-relative',
          quotePreference = 'auto',
        },
      },
    },
  },
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
  -- {
  --   dir = vim.fn.stdpath 'config' .. '/pack/plugins/start/scope-navigation',
  --   name = 'scope-navigation',
  --   lazy = false,
  --   config = function()
  --     require('scope_navigation').setup {
  --       keymap = {
  --         prev = '˚',
  --         next = '∆',
  --         in_scope = '¬',
  --         out_scope = '˙',
  --         visualize = '√',
  --       },
  --
  --       -- Add custom navigable nodes for specific languages
  --       language_nodes = {
  --         typescript = {
  --           'object',
  --           'array',
  --           'ternary_expression',
  --         },
  --       },
  --
  --       -- Custom logic for determining navigable nodes
  --       node_matcher = function(node)
  --         return true
  --         -- -- Example: Treat any node with 'expression' in its type as navigable
  --         -- local node_type = node:type()
  --         -- return string.match(node_type, 'expression') ~= nil
  --       end,
  --
  --       -- Visual feedback settings
  --       tree_visualization = {
  --         max_depth = 25, -- Show deeper nodes
  --         show_unnamed_nodes = true, -- Include unnamed nodes
  --         max_node_length = 40, -- Show longer text previews
  --       },
  --
  --       -- Uncomment to enable debug mode
  --       debug = true,
  --     }
  --   end,
  -- },
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
}
