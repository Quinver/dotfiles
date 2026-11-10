vim.pack.add({
  'https://github.com/windwp/nvim-autopairs.git',
  'https://github.com/rafamadriz/friendly-snippets.git',
  'https://github.com/saghen/blink.cmp.git'
})
require("nvim-autopairs").setup({})
require('blink.cmp').setup({
  completion = {
  trigger = {
    show_on_keyword = true,
    show_on_trigger_character = true,
  },

  accept = {
    auto_brackets = {
      enabled = true,
    },
  },
},

  fuzzy = {
    implementation = "lua",
  },

  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer' },
  },

keymap = {
            ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
            ["<C-e>"] = { "hide", "fallback" },
            ["<CR>"] = { "accept", "fallback" },
            ["<Tab>"] = {
                function(cmp)
                    return cmp.select_next()
                end,
                "snippet_forward",
                "fallback",
            },
            ["<S-Tab>"] = {
                function(cmp)
                    return cmp.select_prev()
                end,
                "snippet_backward",
                "fallback",
            },

            ["<Up>"] = { "select_prev", "fallback" },
            ["<Down>"] = { "select_next", "fallback" },
            ["<C-p>"] = { "select_prev", "fallback" },
            ["<C-n>"] = { "select_next", "fallback" },
            ["<C-up>"] = { "scroll_documentation_up", "fallback" },
            ["<C-down>"] = { "scroll_documentation_down", "fallback" },
        },
})
