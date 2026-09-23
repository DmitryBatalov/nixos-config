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
    # bambu-studio: out since 2026-09-23. Its meta.license pairs AGPL-3.0 with an
    # unfree component, so meta.unfree is true and Hydra never builds it -- the
    # path is not in the binary cache on any channel, and every dependency bump
    # means compiling it again locally. This update's rebuild (same version,
    # 02.05.00.67, new store path) ran the machine out of memory twice. Re-add it
    # with a pinned nixpkgs, the way rider is pinned, or build it by hand once.
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
