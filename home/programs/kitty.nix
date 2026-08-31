{
  programs.kitty = {
    enable = true;
    themeFile = "gruvbox-dark";
    font = {
      name = "JetBrainsMono NF Light";
      size = 13;
    };
  };

  # What xdg-terminal-exec and anything else asking for "a terminal" should open.
  home.sessionVariables.TERMINAL = "kitty";
}
