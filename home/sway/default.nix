{
  pkgs,
  config,
  ...
}: {
  home.file = {
    ".config/sway/wallpaper.png".source = "${pkgs.nixos-artwork.wallpapers.simple-dark-gray-bottom.src}";
    ".config/sway/config".source = ./config;
    ".config/sway/scripts/lock" = { source = ./scripts/lock; executable = true; };
    ".config/sway/scripts/empty_workspace" = { source = ./scripts/empty_workspace; executable = true; };
    ".config/sway/scripts/keyhint-2" = { source = ./scripts/keyhint-2; executable = true; };
    ".config/sway/scripts/power-profiles" = { source = ./scripts/power-profiles; executable = true; };
    ".config/sway/scripts/powermenu" = { source = ./scripts/powermenu; executable = true; };
    ".config/sway/scripts/register-fido2" = { source = ./scripts/register-fido2; executable = true; };
    ".config/sway/scripts/ssh-tunnel-toggle" = { source = ./scripts/ssh-tunnel-toggle; executable = true; };
    ".config/sway/scripts/ssh-tunnel-waybar" = { source = ./scripts/ssh-tunnel-waybar; executable = true; };
    ".config/waybar/config.jsonc".source = ./waybar/config.jsonc;
    ".config/waybar/style.css".source = ./waybar/style.css;
  };
}
