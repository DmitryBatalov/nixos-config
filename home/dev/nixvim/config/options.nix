{
  clipboard = {
    register = "unnamedplus";
  };

  # https://nix-community.github.io/nixvim/NeovimOptions/index.html#globals
  globals = {
    # Set <space> as the leader key
    # See `:help mapleader`
    mapleader = " ";
    maplocalleader = " ";

    # Set to true if you have a Nerd Font installed and selected in the terminal
    have_nerd_font = true;
  };

  opts = {
    number = true;
    relativenumber = true;

    # Enable 24-bit RGB colors
    termguicolors = true;

    mouse = "a";

    # Keep signcolumn on by default
    signcolumn = "yes";

    # Decrease update time
    updatetime = 250;

    # Decrease mapped sequence wait time
    timeoutlen = 300;

    # Configure how new splits should be opened
    splitright = true;
    splitbelow = true;

    # Show which line your cursor is on
    cursorline = true;

    tabstop = 4;
    shiftwidth = 4;

    # Enable break indent
    breakindent = true;

    # Save undo history
    undofile = true;
  };

  colorschemes.tokyonight.enable = true;
}
