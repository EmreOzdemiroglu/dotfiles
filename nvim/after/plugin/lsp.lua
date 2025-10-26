local lsp = require("lsp-zero")

vim.g.lspconfig_suppress_deprecated_notices = true

lsp.preset("recommended")

local cmp = require('cmp')
local cmp_select = {behavior = cmp.SelectBehavior.Select}
local cmp_mappings = lsp.defaults.cmp_mappings({
	['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
	['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
	['<C-y>'] = cmp.mapping.confirm({select = true}),
	['<C-Space>'] = cmp.mapping.complete(),
})

cmp_mappings['<Tab>'] = nil
cmp_mappings['<S-Tab>'] = nil

lsp.set_preferences({
	sign_icons = { }
})

lsp.setup_nvim_cmp({
	mapping = cmp_mappings,
	sources = {
		{ name = 'supermaven' },
		{ name = 'nvim_lsp' },
		{ name = 'buffer' },
		{ name = 'path' },
	}
})

lsp.on_attach(function(client,bufnr)
    local opts = {buffer = bufnr, remap = false}

    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>vd", function() vim.diagnostics.open_float() end, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostics.goto_next() end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostics.goto_prev() end, opts)
    vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
    vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("n", "<C-l>", function() vim.lsp.buf.signature_help() end, opts)
end)

vim.notify = (function(orig_notify)
  return function(msg, level, opts)
    if msg:find("lspconfig.*deprecated") then
      return
    end
    return orig_notify(msg, level, opts)
  end
end)(vim.notify)

