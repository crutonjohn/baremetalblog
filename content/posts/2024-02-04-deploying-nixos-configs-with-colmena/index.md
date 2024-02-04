---
title: Deploying NixOS Configs with Colmena
summary: "Or how I learned to stop worrying and embrace real determinism"
description: "A very brief overview on deploying remote NixOS configurations using Colmena"
author: "Curtis John"
date: 2024-02-04
draft: false
toc: false
images:
  -
categories:
  - nix
tags:
  - colmena
  - nix
  - nixos
---

- [Colmena source on Github](https://github.com/zhaofengli/colmena)
- [Colmena Manual](https://colmena.cli.rs)
- [Point-in-time of Colmena in my main flake]()

### Use Case

I try to keep my cloud compute footprint to a minimum, but there are some very compelling situations in which it is useful to have a service running off-network. Ordinarily someone might just use the tool they know well, in my case Ansible, to manage the configuration of these services. Regardless, you may often find yourself in need of defining the state of a remote system. Here's how you can accomplish this the Nix way with Colmena and Flakes.

First you'll need to install Colmena:

```bash
nix-shell -p colmena
```

And here is an example of a flake to get started:
```nix
{
  description = "Colmena Remote NixOS Management";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.11";
  };

  outputs = { nixpkgs, ... }@inputs:
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };
        specialArgs = {
          inherit inputs;
        };
      };
      myhost = ./hosts/myhost; # this should be a directory with a default.nix inside
    };
}
```

This is where things should start to make sense, implying that you've dabbled in configuring NixOS before. Pay close attention to the highlighted section. This is where we'll define which host we should be deploying to, which user to `ssh` as, and more:

`./hosts/myhost/default.nix`:
```nix {hl_lines=["3-8"],linenostart=1}
{ name, nodes, pkgs, lib, inputs, ... }: {

deployment = {
  targetHost = "myhost.example.com"; # also supports an IP address
  targetPort = 22;
  targetUser = "root";
  buildOnTarget = true;
};

imports =
  [
    ./hardware-configuration.nix
  ];

boot.loader.grub.enable = true;
networking.hostName = "myhost"; # Define your hostname.
networking.useDHCP = false;
networking.interfaces.eth0.useDHCP = true;
time.timeZone = "America/New_York";
i18n.defaultLocale = "en_US.UTF-8";

nix.settings.trusted-users = [ "root" "@wheel" ];

users.users.myuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];
  home = "/home/myuser";
  packages = with pkgs; [
    vim
    tree
    lego
  ];
  openssh.authorizedKeys.keys = [ "ssh-rsa AAAAAAAAAAAAAAAAAAAZZZZZZZZZZZDDDDDDDDDDDDDD" ];
};

environment.systemPackages = with pkgs; [
  inetutils
  mtr
  sysstat
  dig
  openssl
];

services.openssh = {
  enable = true;
  settings.PermitRootLogin = "yes";
};

networking.firewall.allowedTCPPorts = [ 22 80 443 ];
# networking.firewall.allowedUDPPorts = [ ... ];
networking.firewall.enable = true;
networking.usePredictableInterfaceNames = false;

system.stateVersion = "23.05";
}
```

I typically pull the contents of `hardware-configuration.nix` from the target system and place it in my working tree next to `default.nix`.

Naturally you can extend this default file by including more files in the `imports` section:

```nix
...
imports =
  [
    ./hardware-configuration.nix
    ./fail2ban.nix
    ./nginx.nix
    ./docker.nix
  ];
...
```

Once you're happy with your NixOS configurations you can check them into VCS and perform a test build, and then check the output on the target system:

```shell
$ colmena build
warning: Git tree '/home/crutonjohn/Documents/nix' is dirty
[INFO ] Using flake: git+file:///home/crutonjohn/Documents/nix
[INFO ] Enumerating nodes...
[INFO ] Selected all 1 nodes.
      ✅ 7s All done!
 myhost ✅ 5s Evaluated myhost
 myhost ✅ 2s Built "/nix/store/qk58hgf2maspbbl1cmy87x4wql7430fa-nixos-system-myhost-24.05pre-git" on target node

$ ssh nord
Last login: Sat Feb  3 12:27:37 2024 from 73.40.37.26

[myuser@myhost:~]$ ls /nix/store/qk58hgf2maspbbl1cmy87x4wql7430fa-nixos-system-myhost-24.05pre-git
activate               boot.json           etc                 init                    kernel          nixos-version   system
append-initrd-secrets  configuration-name  extra-dependencies  init-interface-version  kernel-modules  specialisation  systemd
bin                    dry-activate        firmware            initrd                  kernel-params   sw
```

If the derivation is to your liking you can go ahead and deploy it:

```shell
colmena apply
```

There are further ways to extend functionality by establishing "tags" for your different target systems like so:

```nix
deployment = {
  targetHost = "webserver01.example.com"; # also supports an IP address
  targetPort = 22;
  targetUser = "root";
  buildOnTarget = true;
  tags = [
    "webserver01"
    "infra"
    "us-east"
  ];
};
```

Deploying configuration to our collection of webservers::

```shell
$ colmena apply --on '@webserver*'
```

### Conclusion

The parallels between Ansible and Colmena make it easy for me to grasp. It's like using Ansible that is natively Nix-aware. I'm in the process of converting a bunch of my own machines to use this deployment method to fully embrace the NixOS life.
