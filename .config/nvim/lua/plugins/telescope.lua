vim.pack.add({
  'https://github.com/nvim-lua/plenary.nvim.git',
  { src = 'https://github.com/nvim-telescope/telescope.nvim.git', version = 'v0.2.0' },
  'https://github.com/nvim-telescope/telescope-ui-select.nvim.git',
})


require('telescope').setup({
  extensions = {
    ['ui-select'] = {
      require('telescope.themes').get_dropdown {

      }
    }
  },

  pickers = {
    find_files = {
      follow = true
    }
  },
})

require('telescope').load_extension('ui-select')
-- Telescope keymaps
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>sf',
  "<cmd>lua require'telescope.builtin'.find_files({ find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>")
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Telescope help tags' })

vim.keymap.set('n', 'gi', require('telescope.builtin').lsp_implementations, { desc = 'LSP Implementations' })

vim.keymap.set('n', 'gr', require('telescope.builtin').lsp_references, { desc = 'LSP References' })


