{inputs, ...}: {
  # nixpkgs-unstable used to be `import`ed separately in users/dmitry/home.nix
  # and home/kube/default.nix. Nix memoises `import` by path but not function
  # application, so those were two independent evaluations of the whole nixpkgs
  # fixed point. Applying it once as an overlay on the system pkgs gives every
  # module -- home-manager included, since useGlobalPkgs is on -- the same
  # single instantiation as `pkgs.unstable`.
  nixpkgs.overlays = [
    (_: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })
  ];
}
