{pkgs, ...}: let
  # Every sheets/<name>.typ becomes <name>.pdf; the picker lists them by name.
  # Typst ships its own fonts, so the build needs nothing from the host.
  pdfs = pkgs.runCommand "cheatsheets" {nativeBuildInputs = [pkgs.typst];} ''
    mkdir $out
    for f in ${./sheets}/*.typ; do
      typst compile "$f" "$out/$(basename "$f" .typ).pdf"
    done
  '';
in {
  xdg.dataFile."cheatsheets".source = pdfs;

  # The viewer of the cheat sheets only: the sway rule sends every zathura
  # window to the scratchpad. Other PDFs keep opening in evince (home/desktop
  # mime list). The picker still tells sheets apart by the window title, which
  # zathura sets to the file path.
  programs.zathura.enable = true;
}
