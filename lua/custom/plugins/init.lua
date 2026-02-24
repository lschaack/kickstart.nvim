vim.o.exrc = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

-- require 'custom.plugins.ts-actions'
require 'custom.plugins.blink'

vim.keymap.set('n', '<leader><tab>', '<c-^><cr>', { desc = '[B]ack' })
vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = 'Show line diagnostics' })
vim.keymap.set('n', '<M-f>', 'f r<enter>^', { desc = 'Break on next space' })
vim.keymap.set('c', '<M-r>', 's/<C-r>0//g<Left><Left>', { desc = '[R]eplace the contents of the default register' })
vim.keymap.set({ 'n', 'v' }, '<M-r>', ':s/<C-r>0//g<Left><Left>', { desc = '[R]eplace the contents of the default register' })
vim.keymap.set('n', '<leader>jk', "oconsole.log('<C-o>p', <C-o>p)<esc>", { desc = 'Paste last yanked text [j]s style' })
vim.keymap.set('n', '<M-j>', '<cmd>cnext<CR>', { desc = 'Go to next quickfix item' })
vim.keymap.set('n', '<M-k>', '<cmd>cprev<CR>', { desc = 'Go to previous quickfix item' })

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
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iffview open' },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = '[G]it diffview [Q]uit' },
    },
    opts = {
      view = {
        merge_tool = {
          layout = 'diff1_plain',
        },
      },
      keymaps = {
        view = {
          { 'n', '<leader>gl', '<cmd>lua require("diffview.actions").cycle_layout()<cr>', { desc = '[G]it diffview cycle [L]ayout' } },
          -- Remap conflict choose keys behind <leader>g to avoid clash with LSP code action
          { 'n', '<leader>gco', '<cmd>lua require("diffview.actions").conflict_choose("ours")()<cr>', { desc = 'Choose ours' } },
          { 'n', '<leader>gct', '<cmd>lua require("diffview.actions").conflict_choose("theirs")()<cr>', { desc = 'Choose theirs' } },
          { 'n', '<leader>gcb', '<cmd>lua require("diffview.actions").conflict_choose("base")()<cr>', { desc = 'Choose base' } },
          { 'n', '<leader>gca', '<cmd>lua require("diffview.actions").conflict_choose("all")()<cr>', { desc = 'Choose all' } },
          { 'n', '<leader>gcO', '<cmd>lua require("diffview.actions").conflict_choose_all("ours")()<cr>', { desc = 'Choose ours (file)' } },
          { 'n', '<leader>gcT', '<cmd>lua require("diffview.actions").conflict_choose_all("theirs")()<cr>', { desc = 'Choose theirs (file)' } },
          { 'n', '<leader>gcB', '<cmd>lua require("diffview.actions").conflict_choose_all("base")()<cr>', { desc = 'Choose base (file)' } },
          { 'n', '<leader>gcA', '<cmd>lua require("diffview.actions").conflict_choose_all("all")()<cr>', { desc = 'Choose all (file)' } },
          -- Disable defaults
          { 'n', '<leader>co', false },
          { 'n', '<leader>ct', false },
          { 'n', '<leader>cb', false },
          { 'n', '<leader>ca', false },
          { 'n', '<leader>cO', false },
          { 'n', '<leader>cT', false },
          { 'n', '<leader>cB', false },
          { 'n', '<leader>cA', false },
        },
        file_panel = {
          { 'n', '<leader>gl', '<cmd>lua require("diffview.actions").cycle_layout()<cr>', { desc = '[G]it diffview cycle [L]ayout' } },
          { 'n', '<leader>gcO', '<cmd>lua require("diffview.actions").conflict_choose_all("ours")()<cr>', { desc = 'Choose ours (file)' } },
          { 'n', '<leader>gcT', '<cmd>lua require("diffview.actions").conflict_choose_all("theirs")()<cr>', { desc = 'Choose theirs (file)' } },
          { 'n', '<leader>gcB', '<cmd>lua require("diffview.actions").conflict_choose_all("base")()<cr>', { desc = 'Choose base (file)' } },
          { 'n', '<leader>gcA', '<cmd>lua require("diffview.actions").conflict_choose_all("all")()<cr>', { desc = 'Choose all (file)' } },
          { 'n', '<leader>cO', false },
          { 'n', '<leader>cT', false },
          { 'n', '<leader>cB', false },
          { 'n', '<leader>cA', false },
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
    'nvim-treesitter/nvim-treesitter-context',
    event = 'BufReadPost',
    opts = {},
    keys = {
      {
        '[c',
        function()
          require('treesitter-context').go_to_context(vim.v.count1)
        end,
        desc = 'Go to [c]ontext',
        silent = true,
      },
    },
  },
  {
    dir = vim.fn.stdpath 'config' .. '/pack/plugins/start/github-url',
    name = 'github-url',
    lazy = false,
    config = function()
      vim.api.nvim_set_keymap(
        'n',
        '<leader>gu',
        "<cmd>lua require('github_url').copy_github_url()<CR>",
        { noremap = true, silent = true, desc = 'Copy [G]ithub [U]rl' }
      )
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
    config = function()
      local finders = require 'lemur.finders'

      require('lemur').setup {
        debug = false,
        highlight = {
          highlight_group = 'LemurTargets',
        },
        finders = {
          -- LSP symbol finders
          functions = {
            finder = finders.lsp_symbols 'Function',
            keymap = '<leader>lf',
            name = 'Functions',
          },

          -- Tree-sitter query finders
          contexts = {
            finder = finders.query('context', 'context'),
            keymap = '<leader>lx',
            name = 'Contexts',
          },

          -- Composed finder: TODO comments
          todos = {
            finder = finders.filter(finders.node_type 'comment', function(node, bufnr)
              local text = vim.treesitter.get_node_text(node, bufnr)
              return text and (text:match 'TODO' or text:match 'FIXME' or text:match 'NOTE')
            end),
            keymap = '<leader>lt',
            name = 'TODO Comments',
          },
        },
      }
    end,
  },
}
