{ config, lib, pkgs, ... }:

with lib;

let
  hydraSrc = builtins.fetchTarball https://github.com/NixOS/hydra/tarball/2f6c2f5622e18b39828528eea1470d78eaec2dc1;
  commonBuildMachineOpt = {
    speedFactor = 1;
    sshKey = "/etc/nix/id_buildfarm";
    sshUser = "root";
    systems = [ "i686-linux" "x86_64-linux" ];
    supportedFeatures = [ "kvm" "nixos-test" ];
  };
in

{
  imports = [ "${hydraSrc}/hydra-module.nix" ];

  # make sure we're using the platform on which hydra is supposed to run
  /*assertions = lib.singleton {
    assertion = pkgs.system == "x86_64-linux";
    message = "unsupported system ${pkgs.system}";
  };*/

  environment.etc = lib.singleton {
    target = "nix/id_buildfarm";
    source = ../secrets/id_buildfarm;
    uid = config.ids.uids.hydra;
    gid = config.ids.gids.hydra;
    mode = "0440";
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      (commonBuildMachineOpt // {
        hostName = "localhost";
        maxJobs = 2;
        supportedFeatures = [ "kvm" "nixos-test" "local" ];
        #mandatoryFeatures = [ "local" ];
      })
    ];
    #extraOptions = "auto-optimise-store = true";
  };

  /*
  users.extraUsers.hydra.openssh.authorizedKeys.keys =
    with import ../ssh-keys.nix; [ bro ];
  users.extraUsers.hydra-www.openssh.authorizedKeys.keys =
    with import ../ssh-keys.nix; [ bro ];
  users.extraUsers.hydra-queue-runner.openssh.authorizedKeys.keys =
    with import ../ssh-keys.nix; [ bro provisioner ];
  */

  programs.ssh.extraConfig = ''
    StrictHostKeyChecking no
  '';

  services.hydra-dev = {
    enable = true;
    #package = hydra;
    logo = (pkgs.fetchurl {
      url    = "https://www.lisberg.dk/images/lisberg/lisberg_logo_v2_160x55.png";
      sha256 = "e7db351923bd573e38b19cf582e1b1bd30f72b36d1dacd7b4b110f88f1833389";
    });
    hydraURL = "https://hydra.maven-group.org";
    notificationSender = "brian@maven-group.org";
    smtpHost = "mail.maven-group.org";
    useSubstitutes = true;
    extraConfig =
    ''
      max_servers 50
      #enable_google_login = 1
      #google_client_id = 816926039128-ia4s4rsqrq998rsevce7i09mo6a4nffg.apps.googleusercontent.com
      #store_uri = s3://nix-cache?secret-key=/var/lib/hydra/queue-runner/keys/cache.thonix.org-1/secret&write-nar-listing=1
      #binary_cache_public_uri = https://cache.thonix.org
      <Plugin::Session>
        cache_size = 32m
      </Plugin::Session>
    '';
    extraEnv = {
      DEBUG = "1";
    };
  };

  systemd.services.hydra-queue-runner.serviceConfig.ExecStart = pkgs.lib.mkOverride 10 "@${config.services.hydra-dev.package}/bin/hydra-queue-runner hydra-queue-runner -vv --debug";

  systemd.services.hydra-user-setup = {
    description = "Create Initial admini user for Hydra";
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    serviceConfig.User = "hydra";
    wantedBy = [ "multi-user.target" ];
    requires = [ "hydra-init.service" ];
    after = [ "hydra-init.service" ];
    environment = config.systemd.services.hydra-init.environment;
    script = ''
      set -o errexit
      if [ ! -e ~hydra/.user-setup-is-complete ]; then
        /run/current-system/sw/bin/hydra-create-user brian --full-name 'Brian Olsen' --email-address 'brian@maven-group.org' --password foobar --role admin
        touch ~hydra/.user-setup-is-complete
      fi
    '';
  };

  users.extraUsers.hydra.home = mkForce "/home/hydra";

  #systemd.services.hydra-queue-runner.restartIfChanged = false;
  #systemd.services.hydra-queue-runner.wantedBy = mkForce [];
  #systemd.services.hydra-queue-runner.requires = mkForce [];

  #networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedTCPPorts = [ 3000 ];

  users.users.hydra.uid = config.ids.uids.hydra;
  users.users.hydra-www.uid = config.ids.uids.hydra-www;
  users.users.hydra-queue-runner.uid = config.ids.uids.hydra-queue-runner;
  users.groups.hydra.gid = config.ids.gids.hydra;

  /*
  programs.ssh.extraConfig = mkAfter
    ''
      ServerAliveInterval 120
      TCPKeepAlive yes
      Host mac1
      Hostname 213.125.166.74
      Port 6005
      Compression yes
      Host mac2
      Hostname 213.125.166.74
      Port 6001
      Compression yes
      Host mac3
      Hostname 213.125.166.74
      Port 6002
      Compression yes
      Host mac4
      Hostname 213.125.166.74
      Port 6003
      Compression yes
      Host mac5
      Hostname 213.125.166.74
      Port 6004
      Compression yes
      Host mac6
      Hostname 208.78.106.251
      Compression yes
      Host mac7
      Hostname 208.78.106.252
      Compression yes
    '';

  services.openssh.knownHosts =
    [
      { hostNames = [ "83.87.124.39" ]; publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVTkY4tQ6V29XTW1aKtoFJoF4uyaEy0fms3HqmI56av8UCg3MN5G6CL6EDIvbe46mBsI3++V3uGiOr0pLPbM9fkWC92LYGk5f7fNvCoy9bvuZy5bHwFQ5b5S9IJ1o3yDlCToc9CppmPVbFMMMLgKF06pQiGBeMCUG/VoCfiUBq+UgEGhAifWcuWIOGmdua6clljH5Dcc+7S0HTLoVtrxmPPXBVZUvW+lgAJTM6FXYIZiIqMSC2uZHGVstY87nPcZFXIbzhlYQqxx5H0um2bL3mbS7vdKhSsIWWaUZeck9ghNyUV1fVRLUhuXkQHe/8Z58cAhTv5dDd42YLB0fgjETV"; }
      { hostNames = [ "[213.125.166.74]:6001" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC4oeixXSB/Ovl3kewykJ2vV82ATOLqPgZDXPdLCmkPRHYt7dy7GNbWrESv3gQvgjEtKaZavthf7aQsJHNa8aKc="; }
      { hostNames = [ "[213.125.166.74]:6002" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBO45JPJIqbQVs3I4RmO01ExRv6krTEnuheAvumgKeb6NwUo6oD1kP4/x8KazoMd4LRAFtdWdwnN3Z7IYmqlmd20="; }
      { hostNames = [ "[213.125.166.74]:6003" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLIMKd1aV7ktAMIZUQV151dbZu/AM7Hszb4dMqwqQ7F8uLOmO+qyyS3nQHrGG6I5VAKbRkbTCn3l0DhYFj7sS6U="; }
      { hostNames = [ "[213.125.166.74]:6004" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLeZFijo43wK8V2/9lXt7OH3axZb4kyZBV7Hn11YdmjPn8KHNkiRNiq9x/AuEhWmpY//9K1XU8RezV5LkGgyirU="; }
      { hostNames = [ "[213.125.166.74]:6005" ]; publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVTkY4tQ6V29XTW1aKtoFJoF4uyaEy0fms3HqmI56av8UCg3MN5G6CL6EDIvbe46mBsI3++V3uGiOr0pLPbM9fkWC92LYGk5f7fNvCoy9bvuZy5bHwFQ5b5S9IJ1o3yDlCToc9CppmPVbFMMMLgKF06pQiGBeMCUG/VoCfiUBq+UgEGhAifWcuWIOGmdua6clljH5Dcc+7S0HTLoVtrxmPPXBVZUvW+lgAJTM6FXYIZiIqMSC2uZHGVstY87nPcZFXIbzhlYQqxx5H0um2bL3mbS7vdKhSsIWWaUZeck9ghNyUV1fVRLUhuXkQHe/8Z58cAhTv5dDd42YLB0fgjETV"; }
      { hostNames = [ "208.78.106.251" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGO7DciBFjk7aLVHCuSghCSMDdGukosx6fvxmAjfW+jAESiaGdAznQTCw2eL5xx9r9vQveaLUL5nHj2LeT6H3tQ="; }
      { hostNames = [ "208.78.106.252" ]; publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBB22WwyB+Y4sp4fm42IoGGW4YWwJ8hC65uLIceChSWCsiAZkaGUvGho8DJpAgJFkdfHdoxutUGEj8ekHAqPU5nI="; }
      { hostNames = [ "hydra.ewi.tudelft.nl" "131.180.119.69" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBAJBHaP+SAMm/eTYciPpQi8x5NULRV8D9/xQPd/SU7s+mQP/TlvLCmgpuHudZMrLgUDWjKclFQThBuhElCvZzHmBcWPP64wzlZdxsizub9525FPAMnhbK5bqQHgji+ilXGTwv+ZvwEC1LJEQz4H5jgXlIgwNzvED4xo8IyLTxKw6TAAAAFQCQE8H+w6xYFMiDLK7tpGaweLj04QAAAIAuES8pfxge4UrDAnKyYEN/IZwTMLznAHoldaa+E+8KYVs7QnhMztJr9kIZWOJOsmEcQ/1SwFJPSU04FbJ25Z25B8jUG6UqMYidiQnzjHqKc29AYo3ZS9xWJ62VS7cW+UeC4zUFMA8jtlaVCfU95uharu+lzM4SecC9+35ObWpn1wAAAIAzgtOQhC7udZJPnvqc4L6AATMoaAQQ3x95nher6oyL3N6Yi6+Sy10v3u5c5uccaDQ/oVjQHBeaFnciNXYTqF0z4u3MmsQ+RtnElJ2+rqqxzvuOUkCms5yNdNq+Ag79MVd5ESlgowtivtZ+p8aH7cIJFab+YkfUpTrZnGDrUl/kEQ=="; }
      { hostNames = [ "ike.ewi.tudelft.nl" "131.180.119.70" ]; publicKey = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGNzlom/R/lJ0TZb2HLm19V+BoifFoENHocIJ4MiV9FQCOUlLLQh7kZMKtzVJdM+n1q1BqLp6bll6U7PsLUKAg+rgDU2saHd8ScaeZqhdmWpO4lMMxpNreAETsY1txpSatT4aHvjJMTlT1pmaLiqfhCenqxaqeH3/3XPkVfK48Nk+mo8w=="; }
      { hostNames = [ "kenny.ewi.tudelft.nl" "131.180.119.71" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBANmEz1UzFCfab/a/VjWFr/mrwB/trcMPXg15U6vy6iprg34vKbanefX0BJOyBUdueNenSAcuC18mDH/aYrCb7Y5CyhLQH8w7YaTpehbpMIS4SJGC3hRd4LSE7mYBUQf396Syp5coA0CHZJZ6lhLYspZCHDonm1vAfVyMqJOSubPlAAAAFQCNFpbZrLGfyPcWss7e+iF/i/xszwAAAIBONlTGHQpDNadffT9NQ3l8hFe8P9MJvRIUW1q/VEzRRBcbBWQnYh35YXMYPyrZaXaGILv6ma462PUu23VBoF9/twxMRBkKEuWfe1c+YM0w7wd6BA5L99GMhQGsy8ahSyD3FN3sW9kqqzryYt0KgCqCTDo/HAp51UYCeXuflABv8QAAAIB3lV9cSaUrso1jMhkPJU+oIuUjGyd+8stWGp2lXc0+ccud+tkx9rpTr2oZOcM6/2NKSvz6XXQ+9l/iTQxSIlrJpi337Hpv4qkjB2R0cID+xxKT5Y9NLxMtaEipwvpAX4GRtpzK0KJB9x4CM8jiF1SIRPQkBKZme8XPq8B3kdCEIA=="; }
      { hostNames = [ "kyle.ewi.tudelft.nl" "131.180.119.72" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBAJtmR7tVnalxWtoAc7Xewomickd5qB4Zc7U/+P3OAweqdmYB9uzJPOIfKcuw3o02du1exalgtcUKeqGCPWB8uAwScDB/sbMuN9vxIoogYsT4aZFlgzUM9Nvan9Q4jJ9fi9wBD0KJWSTf3WSQm18p/NQ7hwXqHA5ry2HFCrP005oBAAAAFQDRK3bgyIpLB0gQnRwSK9RScmekvQAAAIEAhZVMQBUW13XAMHQxPVMug9kW6uAp/Dk/nm124KIeeCDgV+SMCSntwdE7opz+CfR2GbMVOKYRlx8TJJhuI4ubPYT0HrcmP9snAgidwXME8DZCdxfdz7c04ggTrww3Z/yc0dS5rDv7OF3dO/44WXFzOwWV8rV6ihf4lY+WrhDeITwAAACBAIbOt7wn5moefey3ZIZQ3Ls7neP69b35oYpAjtb/8rOMMe+umg2jACMP/G/pGn77cZ8XTN6eVA6oJTSKAzJQhxQBQeBMk96cJHKOtstAMTW++5PK0x0iMehn/NMxVf905oTlTNPyNuf2xOK3u0MtzFAn03qWFFeIXT8db2NKckvs"; }
      { hostNames = [ "lucifer.ewi.tudelft.nl" "131.180.119.73" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBAPrrqKNWZX/3uDOpxrIiiw25uiyWdoxw6KBqLB073Pa6wCttMEzNMHRXYZ8DeKYu4wme0b0siST+sXHDAiuYfyeTpr0IIQSoSCmVkEbV+qddSQG3j1nsQS/UoOa9+NLeT1A/VjvHLY+84OfCj2cIsH8K5pq2kRgzO8mPMCiBqIvVAAAAFQDM7cuqhTdSz19NPFFTLsxumhDsywAAAIBEnvmdidhrWcyJ8PFn65IaRnU5wrxbfza/+yWXQzsEo83ROIJn9rsa497fm1ZIEddD0GjJcQDYhHRoS1M3Yd4NuPSd4677FnRZwU1oVC+KvjslOfdaWCrSpBZ9Ku6vc8/27gF+HgLdG2mXIqkKMbtEiREOB1RD1C3+1fJ2o2BjjgAAAIEA+uPTp8aZIu9o/E0jyIDQXT6LZ37jTSK2M2LJw9kT1GWpJfLjnntUfvAUmJOoWAaEKuy2abafHLPrefnqKzIWy8OKPUzfwW+Kqre6SUNyKxeEXN+rdqR7LIZhYweoX8tHxbNCf2HkwJvZQw7lx9ACfeOkA5N56krb7kZqtCP6N6I="; }
      { hostNames = [ "stan.ewi.tudelft.nl" "131.180.119.74" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBAL0SlYpGjDjPKrLIwoltYHHTYo/d6Ct2FQZKh4ltKOszWPYYAbs/YNSm2eFkvj0CGc3aastFuebz6+pRfvGMvqi4q6IoHwVvOkbWMadyuqrWIO+Z1YemZP/GAG69pLy+UyoydiSI83ycwPe4YARAU/cpBMNKJZbSxyrO80XatmtRAAAAFQC291WK+9M8+zI4KAtk6EqX0vqQ1QAAAIBd1YgRfdfRdu60BpR+3/YMbSYZMjRLFPyoSgmEQR2TtKfqsuKTsTREzB20iMgFlhEWb6C4r5y6jYDU85OOnvpf7zne22j6bKFDIiAbgsjUFHK1EB7+TBltf5yqq0FyNOy/PnLqVzOeGaUeCOc3Ris71Lxkm60oVF4mjut2d2UJ6AAAAIByuCH1bIIRb4za4yiiFQUz2CBX1XHhBn/h/LhNMLuyCTciG6tkppGBAgq5rWrNhjaEc7dIFgZR+E1wE5PQzWG/TBiXctwCOqOOErDB5b95jO2EntIhi8x5PO9Ef6jgis4QRsBIZiENDDeQHxFHCv4q+10TpyV+625O8TXkkcxl0g=="; }
      { hostNames = [ "wendy.ewi.tudelft.nl" "131.180.119.77" ]; publicKey = "ssh-dss AAAAB3NzaC1kc3MAAACBAIDHVZ/xtcBsNHJ6qYxa3f1RX5k+SaRwgemCfIBSOgL8AGnsvD+OomlGg/eDhJU60AzFSZBQjKtrgRYWmAnzqSMOtfb9IIT5JfG5h/27LVjaaq29Mv+PcDpuPLuFNW3G50hDD1gA0hQhrZdZBkBv9MBaJgizFUjV9tb8KZIRS+MDAAAAFQC8YJViwihyk0oIHOgBfBifiTku6QAAAIBHadEeonXcbDWH6Q5esR1IU7dFMw/zS/wg9IgH0b7lRZBkyVkS0yxfJ7r8swCQ0Loh9dvLtbHLXMlegNfEFv3nbmZqE4copO/2wOM7SqhJRykByMFEhY28t1O1M4rYmzqXs92VUtc5xiTR/lv93C05KSkOl7rUfw43jsWgQAzIkgAAAIB3s4ntqW4H0TdNJFOpaVq1wgRJi768BAVq7MnuIKpFfjGiO7P1Wtk+6/8rzP3gx4cFELZWfJiDHZO5pJE2UGtx5yioQihg4nnZPxTw4FJS/Olf15S2CB/EsYgn9NlUAfOR29ApwasHAy8uP89iOv94cP3YMnWoSi0jkq8iSrSy7Q=="; }
    ];
  */
}