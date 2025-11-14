{pkgs ? import <nixpgks> {}}:
(pkgs.buildFHSEnv {
  name = "rider-env";
  targetPkgs = pkgs: (with pkgs; [
    dotnetCorePackages.dotnet_8.sdk
    dotnetCorePackages.dotnet_8.asptnetcore
  ]);
  multiPkgs = pkgs: (with pkgs; []);
  runScript = "nohup rider &";
})
.env
