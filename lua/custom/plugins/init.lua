vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

require 'custom.plugins.ts-actions'
require 'custom.plugins.blink'

vim.keymap.set('n', '<leader><tab>', '<c-^><cr>', { desc = '[B]ack' })

return {
  'mg979/vim-visual-multi',
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      settings = {
        tsserver_file_preferences = {
          quotePreferences = 'single',
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
}
