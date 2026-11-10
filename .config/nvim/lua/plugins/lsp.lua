vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig.git' })

vim.lsp.enable('clangd')
vim.lsp.enable('bashls')
vim.lsp.enable('jsonls')
vim.lsp.enable('cssls')
vim.lsp.enable('gopls')
vim.lsp.enable('vtsls')
vim.lsp.enable('omnisharp')
vim.lsp.enable('emmet_ls')
vim.lsp.enable('html')
vim.lsp.enable('eslint')
vim.lsp.enable('jsonls')
vim.lsp.enable("basedpyright")

local capabilities = vim.lsp.protocol.make_client_capabilities()
---@diagnostic disable-next-line: need-check-nil
capabilities.textDocument.completion.completionItem.snippetSupport = true

vim.lsp.enable('emmylua_ls')
