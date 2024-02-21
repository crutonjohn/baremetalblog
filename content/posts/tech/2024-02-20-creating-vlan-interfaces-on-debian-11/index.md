---
title: "Creating VLAN Interfaces on Debian 11"
summary: "How to create a VLAN interface on Debian 11"
description: "and probably other debian based distros"
date: 2024-02-20
draft: false
toc: false
images:
categories:
  - linux
  - networking
tags:
  - linux
  - networking
  - debian
---

I've had trouble finding good documentation on how to create VLAN interfaces on a Debian machine, so here I am tossing my proverbial hat into the ring in hopes that someone will find this useful.

Many guides will tell you to just edit your `/etc/network/interfaces` file and have it look something like this:

```bash
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s31f6
iface enp0s31f6 inet static
     address 192.168.130.56
     netmask 255.255.255.0
     gateway 192.168.130.1

# The VLAN interface
auto enp0s31f6.3002
iface enp0s31f6.3002 inet dhcp
```

In my experience this __will not work__. The interface will not show up and `ifup` will not activate it.

What you want to do instead is define a file in `/etc/network/interfaces.d/` like so:

```bash
auto enp0s31f6.3002
iface enp0s31f6.3002 inet dhcp
    hwaddress ether 02:e7:37:19:b0:47
```

For VLAN interfaces in which you need to make up a MAC address I use a one-liner like this to avoid MAC duplication in my local network:

```bash
echo $(hostname)|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/'
```

So yeah, this is how I got it working in my case. Hope this helps you!
