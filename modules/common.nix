{ config, pkgs, ... }:

{
  # let's make sure only NixOS can handle users
  users.mutableUsers = false;

  # less paranoia
  networking.firewall.allowPing = true;

  nix = rec {
    # use nix sandboxing for greater determinism
    useSandbox = false;

    # make sure we have enough build users
    nrBuildUsers = 30;

    # if our hydra is down, don't wait forever
    extraOptions = ''
      connect-timeout = 10
      build-timeout = 18000
    '';

    # use our hydra builds
    # trustedBinaryCaches = [ "https://cache.nixos.org" "https://hydra.snabb.co" ];
    trustedBinaryCaches = [ "https://cache.nixos.org" "https://hydra.nixos.org"];
    binaryCaches = trustedBinaryCaches;
    binaryCachePublicKeys = [ 
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
    ];
  };
}