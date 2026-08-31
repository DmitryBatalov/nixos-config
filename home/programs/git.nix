{
  programs = {
    git = {
      enable = true;
      ignores = [".claude/"];
      settings = {
        user = {
          name = "dmitry.batalov";
          email = "dmtiryabat@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };

    # TUI for git
    lazygit.enable = true;
  };
}
