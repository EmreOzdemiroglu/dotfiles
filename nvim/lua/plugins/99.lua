return {
  "ThePrimeagen/99",
  config = function()
    local _99 = require("99")

    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    _99.setup({
      model = "opencode/minimax-m2.5-free",
      logger = {
        level = _99.DEBUG,
        path = "/tmp/" .. basename .. ".99.debug",
        print_on_error = true,
      },
      tmp_dir = "./tmp",
      completion = {
        custom_rules = { "~/.config/nvim/custom_rules" },
          files = {
              enabled= true,
              exclude = { "node_modules", ".venv", "venv"},
          },
          source = "cmp",
      },
      md_files = { "AGENT.md" },
    })

    -- core
    vim.keymap.set("v", "<leader>9v", function() _99.visual() end)
    vim.keymap.set("n", "<leader>9x", function() _99.stop_all_requests() end)
    vim.keymap.set("n", "<leader>9s", function() _99.search() end)
    vim.keymap.set("n", "<leader>9d", function() _99.vibe() end)

    -- telescope pickers
    vim.keymap.set("n", "<leader>9m", function()
      require("99.extensions.telescope").select_model()
    end)

    vim.keymap.set("n", "<leader>9p", function()
      require("99.extensions.telescope").select_provider()
    end)
  end,
}

