return {
  {
    "tanvirtin/monokai.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("monokai").setup({
        palette = {
          base2 = "#000000",
        },
        custom_hlgroups = {
          Normal = { bg = "NONE" },
          NormalNC = { bg = "NONE" },
          SignColumn = { bg = "NONE" },
          LineNr = { bg = "NONE" },
          CursorLineNr = { bg = "NONE" },
          EndOfBuffer = { bg = "NONE" },
        },
      })
    end,
  },
}
