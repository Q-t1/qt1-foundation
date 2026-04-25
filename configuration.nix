{config, lib, pkgs, ... }:
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
    interfaces.br-lan = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.1.230";
          prefixLength = 24;
        }
      ];
    };
    bridges.br-lan = {
      interfaces = [ "enp2s0" ];
    };
    wireless.enable = false;
    defaultGateway = "192.168.1.254";
    nameservers =  [ "1.1.1.1" "8.8.8.8"];
  };

  time.timeZone = "Europe/Paris";

  console.keyMap = "fr";

  users.users.qt1 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "incus-admin" "video" "render" ];
    packages = with pkgs; [
      vulkan-tools
      jq
      yq
      skopeo
      kubernetes-helm
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

  environment.systemPackages = with pkgs; [
    wget
    git
    vim
    iputils
    ghostty
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        PubkeyAuthentication = "yes";
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
    xserver.videoDrivers = [ "amdgpu" ];
  };

  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vulkan-tools
      ];
    };
    enableRedistributableFirmware = true;
  };

  virtualisation.incus = {
    enable = true;
    ui = {
      enable = true;
    };
    package = pkgs.incus;
    preseed = {
      networks = [
        {
          config = {
            "ipv4.address" = "10.0.0.1/24";
            "ipv4.nat" = "true";
          };
          name = "incusbr0";
          type = "bridge";
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              size = "20GiB";
              type = "disk";
            };
          };
        }
        {
          name = "lan";
          description = "LAN bridged VMs";
          devices = {
            eth0 = {
              name = "eth0";
              nictype = "bridged";
              parent = "br-lan";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              size = "20GiB";
              type = "disk";
            };
          };
        }
      ];
    };
  };
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 8443 ];
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  boot.kernelModules = [ "overlay" "br_netfilter" ];

  # Runtime config via systemd override
  systemd.services.incus-post-init = {
    description = "Incus HTTPS config";
    serviceConfig = {
      User = "root";
    };
    after = [ "incus.service" ];
    requires = [ "incus.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.incus ];
    script = ''
      incus config set core.https_address ":8443" || true
      incus config trust add-certificate /opt/incus/incus-ui.crt || true 
      if ! incus storage list | grep -q default; then
        echo "No default pool. Proceed to creation."
        incus storage create default btrfs source=/incus-pool
        incus config set storage.default_pool default
      else
        echo "Default pool already exists. Skipping creation..."
      fi
    '';
  };

  system.stateVersion = "25.11";
}

