{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.desktop.fonts;
in {
  options.local.desktop.fonts.enable =
    lib.mkEnableOption "the Nerd Fonts this setup's terminal and bar assume";

  config = lib.mkIf cfg.enable {
    fonts = {
      packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
      ];

      # user defined fonts
      # the reason there's Noto Color Emoji everywhere is to override DejaVu's
      # B&W emojis that would sometimes show instead of some Color emojis
      fontconfig.defaultFonts = {
        monospace = ["JetBrainsMono Nerd Font"];
      };
    };
  };
}
