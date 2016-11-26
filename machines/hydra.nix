{ config, lib, pkgs, ... }:
{
  require = [
    ./../modules/common.nix
    ./../modules/hydra-master.nix
    ./../modules/hydra-slave.nix
  ];
}