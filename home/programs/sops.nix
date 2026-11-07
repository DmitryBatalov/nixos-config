{pkgs, ...}: {
  # sops decrypts with the age identity on the Rutoken: the plugin asks for the
  # PIN and a touch. The identity file is a stub naming the token, not a key,
  # but sops only looks for keys.txt by default.
  home.packages = [pkgs.sops pkgs.age-plugin-fido2-hmac];
  home.sessionVariables.SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/fido2.txt";
}
