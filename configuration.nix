{ config, lib, pkgs, ... }:
  let
    kubeMasterIP = "127.0.0.1";
    kubeMasterAPIServerPort = 6443;
  in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  swapDevices = [ 
    { 
      device = "/swapfile"; 
      size = 8192;
    } 
  ];

  networking = {
    hostName = "nixos-foundation";
    useDHCP = false;
    dhcpcd.enable = false;
    interfaces.enp2s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.1.230";
          prefixLength = 24;
        }
      ];
    };
    wireless.enable = false;
    defaultGateway = "192.168.1.254";
    nameservers =  [ "1.1.1.1" "8.8.8.8"];
  };

  time.timeZone = "Europe/Paris";

  console.keyMap = "fr";

  users.users.qt1 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
    packages = with pkgs; [
      jq
      kubernetes-helm
      clusterctl
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDtASdfLMatnUWsdJIjIvIXqXrnmABAznN/6mji1/rzRLqrusduqahyi4htTRvOuue3vrhUqeywiRTNTpzthfhVqeF5WehE1wAPkbgGwAvxC8ltqLPza6KkfZF0WXdXj/MsKJDTJUwui+acbyJocuMz0teJOhURoaEetXzr+ffj6P9Txz7uX6KN8D2DYGi9WvG8QPdlF/89f5vtCx4GFrKkdSET+yNC3PEcf+X8wDoL+ztuvcTGLb4rC42NzLJ82VCAYZ6KS085s8GD+lcgU/jxpRUeCVoY7Ciym/VKs2oxVsyM45fP+d33BJmqV+WGgVLHz0T4y05HOS6CBLObbXZYLfDg7jNl/MVxVktNRfvPLr23z8IvUL1DR8lHIqc6jesFMe8W5PuaoxwzQIhRl8ywGT/rVq1btMiS41mqo/86pZAFtehTt04A3GbMVGB7NNO3tmaVbUlr/aSFdB/hLr0pU3uuZQsHCipZ/3+IGs7erU1r2VVNhnxd/JcDJEVstd8= quentin@MacBook-Air-de-Quentin.local"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" ];
    custom = "$HOME/.oh-my-zsh/custom/";
    theme = "powerlevel10k/powerlevel10k";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    iputils
    ghostty
    k3s
    ];

  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  virtualisation.libvirtd = {
    enable = true;
  };

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--write-kubeconfig-mode 640"
      "--write-kubeconfig-group k3sconfig"
    ];
  };

  # required for rootless access
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 6443 ];
  
  system.stateVersion = "25.11"; # Did you read the comment?
}

