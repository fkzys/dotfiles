return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash", "lua", "json", "vim", "go", "rust", "python",
        "html", "css", "javascript", "toml", "htmldjango"
      },
      highlight = {
        enable = true,
      },
    },
  },
}

