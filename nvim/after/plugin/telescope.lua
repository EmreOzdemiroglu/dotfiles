local telescope = require('telescope')
local builtin = require('telescope.builtin')

-- Telescope ayarlarını yapılandır
telescope.setup {
  defaults = {
    layout_strategy = 'horizontal', -- Yatay düzen
    layout_config = {
      width = 0.95, -- Telescope penceresi ekranın %95'ini kaplasın
      height = 0.95, -- Yükseklik %95
      preview_width = 0.6, -- Preview paneli toplam genişliğin %70'i olsun
    },
  },
  pickers = {
    find_files = {
      layout_config = {
        preview_width = 0.6, -- find_files için preview %70
      },
    },
    git_files = {
      layout_config = {
        preview_width = 0.6, -- git_files için preview %70
      },
    },
  },
}

-- Keybinding'ler
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', function()
  builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)
