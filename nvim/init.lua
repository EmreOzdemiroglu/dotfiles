require("mreative")
vim.cmd('colorscheme rose-pine')
vim.o.autoread = true
    pattern = "*",
    vim.api.nvim_create_autocmd("CursorHold", {
    command = "checktime",
})
vim.g.netrw_banner = 0


