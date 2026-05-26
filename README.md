## How to install

The command to rebuild and apply changes.

```bash
sudo nixos-rebuild switch --flake .#nixos
```

## Useful commands

The command to run nvim with nix lsp.

```bash
nix run github:notashelf/nvf#nix .
```

## Updating flake lockfiles

The root flake references `claude-config` and `nixvim-config` as `path:` inputs,
so their entries in the root `flake.lock` re-lock automatically. The sub-flakes'
own `flake.lock` files (which pin their `nixpkgs`) only update when
`nix flake update` is run inside each one, so update all five:

```bash
nix flake update
(cd home/dev && nix flake update)
(cd home/programs/dotnet-dump && nix flake update)
(cd home/dev/nixvim && nix flake update)
(cd home/dev/claude && nix flake update)
```
