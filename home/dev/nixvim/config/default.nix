{ fff-nvim-plugin, ... }:
{
  imports = [
    ./options.nix
    ./keymaps.nix
    ./plugins.nix
    ./completion.nix
    ./autocmds.nix
  ];

  extraPlugins = [ fff-nvim-plugin ];
}
