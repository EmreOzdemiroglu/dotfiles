-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  use 'ThePrimeagen/vim-be-good'
  use 'mfussenegger/nvim-jdtls'

  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.8',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }
  use({ 'rose-pine/neovim', as = 'rose-pine' })
 -- use {"supermaven-inc/supermaven-nvim",
  --config = function()
   -- require("supermaven-nvim").setup({})
  --end,
-- }
--
-- Inside your packer startup function

use {
  'NickvanDyke/opencode.nvim',
  config = function()
    -- `opencode.nvim` passes options via a global variable instead of `setup()` for faster startup
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`
    }
    -- Required for `opts.auto_reload`
    vim.opt.autoread = true
    -- Recommended keymaps
    vim.keymap.set('n', '<leader>oA', function() require('opencode').ask() end, { desc = 'Ask opencode' })
    vim.keymap.set('n', '<leader>oa', function() require('opencode').ask('@cursor: ') end, { desc = 'Ask opencode about this' })
    vim.keymap.set('v', '<leader>oa', function() require('opencode').ask('@selection: ') end, { desc = 'Ask opencode about selection' })
    vim.keymap.set({ 'n', 'v' }, '<leader>os', function() require('opencode').select() end, { desc = 'Select opencode prompt' })
    -- Example: keymap for custom prompt
    vim.keymap.set('n', '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, { desc = 'Explain this code' })
  end,
}
  use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }
    use('nvim-treesitter/playground')
    use('ThePrimeagen/harpoon')
    use('mbbill/undotree')
    use('tpope/vim-fugitive')
     use {
	    'VonHeikemen/lsp-zero.nvim',
	    branch = 'main',
	    requires = {
		    -- LSP Support
		    {'neovim/nvim-lspconfig'},             -- Required
		    {'williamboman/mason.nvim'},           -- Optional
		    {'williamboman/mason-lspconfig.nvim'}, -- Optional

		    -- Autocompletion
		    {'hrsh7th/nvim-cmp'},     -- Required
		    {'hrsh7th/cmp-nvim-lsp'}, -- Required
		    {'L3MON4D3/LuaSnip'},     -- Required
	    }
     }
     }
end)
