{pkgs, ...}: {
  imports = [
    ../../home/core.nix

    ../../home/i3
    ../../home/rofi
  ];

  programs = {
    git = {
      enable = true;
      userName = "dmitry.batalov";
      userEmail = "dmtiryabat@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
      };
    };

    bash = {
      enable = true;
      shellAliases = {
        lg = "lazygit";
      };
    };

    alacritty = {
      enable = true;
    };

    lazygit = {
      enable = true;
    };
  };
}
