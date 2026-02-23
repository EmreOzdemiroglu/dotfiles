return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = "auto",
        dark_variant = "main",
      })
      vim.cmd.colorscheme("rose-pine")
    end,
  },

  {
    "NickvanDyke/opencode.nvim",
    event = "VeryLazy",
    init = function()
      vim.g.opencode_opts = {}
      vim.opt.autoread = true
    end,
    keys = {
      {
        "<leader>oA",
        function()
          require("opencode").ask()
        end,
        desc = "Ask opencode",
      },
      {
        "<leader>oa",
        function()
          require("opencode").ask("@cursor: ")
        end,
        mode = "n",
        desc = "Ask opencode about this",
      },
      {
        "<leader>oa",
        function()
          require("opencode").ask("@selection: ")
        end,
        mode = "v",
        desc = "Ask opencode about selection",
      },
      {
        "<leader>os",
        function()
          require("opencode").select()
        end,
        mode = { "n", "v" },
        desc = "Select opencode prompt",
      },
      {
        "<leader>oe",
        function()
          require("opencode").prompt("Explain @cursor and its context")
        end,
        desc = "Explain this code",
      },
    },
  },

  {
    dir = "/Users/mreative-air/dev/comment2code.nvim",
    name = "comment2code.nvim",
    cond = function()
      return vim.fn.isdirectory("/Users/mreative-air/dev/comment2code.nvim") == 1
    end,
    config = function()
      require("comment2code").setup({
        model = "opencode/big-pickle",
        mode = "auto_linear",
        debounce_ms = 500,
        keymaps = {
          manual_trigger = "<leader>ai",
          process_all = "<leader>aA",
        },
      })
    end,
  },

  { "nvim-lua/plenary.nvim", lazy = true },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")

      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.95,
            height = 0.95,
            preview_width = 0.6,
          },
        },
        pickers = {
          find_files = {
            layout_config = { preview_width = 0.6 },
          },
          git_files = {
            layout_config = { preview_width = 0.6 },
          },
        },
      })

      vim.keymap.set("n", "<leader>pf", builtin.find_files, {})
      vim.keymap.set("n", "<C-p>", builtin.git_files, {})
      vim.keymap.set("n", "<leader>ps", function()
        builtin.grep_string({ search = vim.fn.input("Grep > ") })
      end)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "javascript", "typescript", "python", "c", "lua", "vim", "vimdoc", "query" },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
    },
  },

  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local mark = require("harpoon.mark")
      local ui = require("harpoon.ui")

      vim.keymap.set("n", "<leader>a", mark.add_file)
      vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)
      vim.keymap.set("n", "<C-h>", function()
        ui.nav_file(1)
      end)
      vim.keymap.set("n", "<C-t>", function()
        ui.nav_file(2)
      end)
      vim.keymap.set("n", "<C-n>", function()
        ui.nav_file(3)
      end)
      vim.keymap.set("n", "<C-s>", function()
        ui.nav_file(4)
      end)
    end,
  },

  {
    "mbbill/undotree",
    keys = {
      {
        "<leader>u",
        function()
          vim.cmd.UndotreeToggle()
        end,
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      local cmp = require("cmp")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      local cmp_select = { behavior = cmp.SelectBehavior.Select }
      local cmp_mappings = cmp.mapping.preset.insert({
        ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
      })

      cmp_mappings["<Tab>"] = nil
      cmp_mappings["<S-Tab>"] = nil

      cmp.setup({
        mapping = cmp_mappings,
        sources = {
          { name = "nvim_lsp" },
          { name = "buffer" },
          { name = "path" },
        },
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
      })

      local capabilities = cmp_nvim_lsp.default_capabilities()
      require("mason").setup({})
      require("mason-lspconfig").setup({
        handlers = {
          function(server_name)
            require("lspconfig")[server_name].setup({
              capabilities = capabilities,
            })
          end,
        },
      })
    end,
  },

  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      presets = {
        command_palette = true,
        long_message_to_split = true,
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
      },
    },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    opts = {
      indent = { char = "│" },
      scope = { enabled = true },
    },
  },
}
