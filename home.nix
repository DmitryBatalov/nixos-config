{
  config,
  pkgs,
  ...
}: {
  home = {
    username = "dmitry";
    homeDirectory = "/home/dmitry";
  };

  programs = {
    git = {
      enable = true;
      userName = "dmitry.batalov";
      userEmail = "dmtiryabat@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
      };
    };
    lazygit.enable = true;
    neovim.enable = true;
  };

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    surf
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      lg = "lazygit";
    };
  };

  #home.file.".config/i3".source = ./config/i3;
}
