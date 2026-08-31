{
  inputs,
  pkgs,
  ...
}: {
  # Applications with no configuration to speak of. Anything that carries
  # settings lives in its own module under home/programs or home/desktop.
  home.packages = [
    pkgs.flameshot
    pkgs.unstable.telegram-desktop
    pkgs.libreoffice-qt6-fresh
    pkgs.freecad
    pkgs.bambu-studio
    pkgs.obsidian
    pkgs.vlc
    pkgs.evince
    pkgs.xournalpp
    pkgs.typst
    pkgs.mongosh
    # mongodb-compass: dropped 2026-08-10. Its package.nix calls wrapGAppsHook
    # manually outside fixupPhase, so $output is unset; the re-entrancy guard
    # added to wrap-gapps-hook in nixpkgs 26.05.7273 then dies with
    # "wrapGAppsHookHasRunForOutput: bad array subscript". Unfree, so it is
    # never in the binary cache and always builds locally. Re-add once fixed.
    pkgs.mariadb.client
    inputs.nixvim-config.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.claude-config.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.xdg-terminal-exec
  ];
}
