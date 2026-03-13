vim.opt.clipboard = "unnamedplus"

vim.cmd([[let g:loaded_matchparen = 1]])

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4

vim.opt.fixendofline = true
vim.opt.endofline = true

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*',
    callback = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[%s/\s\+$//e]])
        vim.cmd([[%s/\n\+\%$//e]])
        pcall(vim.api.nvim_win_set_cursor, 0, pos)
    end,
})

require("config.lazy")
