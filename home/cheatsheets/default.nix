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

  # The viewer of the cheat sheets only: its window title is the file path,
  # which lets the sway rule send these windows -- and no other PDF -- to the
  # scratchpad. Other PDFs keep opening in evince (home/desktop mime list).
  programs.zathura.enable = true;
}
