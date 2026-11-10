vim.pack.add({
  'https://github.com/zaldih/themery.nvim.git',
  'https://github.com/folke/tokyonight.nvim.git',
  'https://github.com/Mofiqul/vscode.nvim.git',
  'https://github.com/ribru17/bamboo.nvim.git',
})

require('tokyonight').setup({
  transparent = true
})

require('bamboo').setup({
  transparent = true
})

require('themery').setup({
  themes = {'tokyonight', 'vscode', 'bamboo'},
  livePreview = true,
})

