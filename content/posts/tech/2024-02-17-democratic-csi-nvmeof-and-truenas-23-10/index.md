---
title: Democratic CSI NVMEof and TrueNAS 23.10
summary: "A patch to get NVMEoF working on TrueNAS 23.10"
description: "Breaking News: Upgrades can break stuff"
date: 2024-02-17
draft: false
toc: false
images:
categories:
  - kubernetes
  - storage
tags:
  - kubernetes
  - storage
  - truenas
  - nvmeof
---

A recent upgrade I made to jump from TrueNAS SCALE version 22 "Bluefin" to version 23 "Cobia" wound up breaking my NVMEoF storage. I use Democratic CSI in my Kubernetes cluster to orchestrate creating NVMEoF volumes and attaching them to pods for PVCs. Democratic CSI can create a block volume in TrueNAS, add that volume to the running NVMEoF config, and ultimately do all the wiring within your cluster.

Democratic CSI distributes a bash script mean to run on your TrueNAS server which gets executed after the system boots. The script sets up NVMEoF and imports a config file containing your volumes. This script relies on Python to set up the NVMEoF client library. As a part of the changes introduced in TrueNAS 23.10 (I didn't read the patch notes) something changed with the underlying system's Python installation. This caused the script provided by Democratic CSI to stop workin altogether.

I figured out how to get this working again using some very creative Python virtual environment stuff, as well as breaking the script up into various functions:

```bash
#!/bin/bash

# simple script to 'start' nvmet on TrueNAS SCALE
#
# to reinstall nvmetcli simply rm /usr/sbin/nvmetcli

# debug
#set -x

# exit non-zero
set -e

SCRIPTDIR="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"
cd "${SCRIPTDIR}"

: "${NVMETCONFIG:="${SCRIPTDIR}/nvmet-config.json"}"
: "${NVMETVENV:="${SCRIPTDIR}/nvmet-venv"}"

export PATH=${HOME}/.local/bin:${PATH}


main () {

  kernel_modules
  setup_venv
  install_nvmetcli
  nvmetcli_restore

}

kernel_modules () {

  modules=()
  modules+=("nvmet")
  modules+=("nvmet-fc")
  modules+=("nvmet-rdma")
  modules+=("nvmet-tcp")

  for module in "${modules[@]}"; do
    modprobe "${module}"
  done

}

setup_venv () {

  rm -rf ${NVMETVENV}
  python -m venv ${NVMETVENV} --without-pip --system-site-packages
  activate_venv
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python get-pip.py
  rm get-pip.py
  deactivate_venv

}

activate_venv () {

  . ${NVMETVENV}/bin/activate

}

deactivate_venv () {

  deactivate

}

install_nvmetcli () {

  if [[ ! -d nvmetcli ]]; then
    git clone git://git.infradead.org/users/hch/nvmetcli.git
  fi

  cd nvmetcli

  activate_venv

  # install to root home dir
  python3 setup.py install

  # install to root home dir
  pip install configshell_fb

  # remove source
  cd "${SCRIPTDIR}"
  rm -rf nvmetcli

  deactivate_venv

}

nvmetcli_restore () {

  activate_venv
  cd "${SCRIPTDIR}"
  nvmetcli restore "${NVMETCONFIG}"
  deactivate_venv
  touch /var/run/nvmet-config-loaded
  chmod +r /var/run/nvmet-config-loaded

}

main
```

The most up-to-date script can be found in [this github gist](https://gist.github.com/crutonjohn/9fa0bb368149cff189fa2ae89021a9e8) which I will try to keep up-to-date.

I am also working with Democratic CSI to get it upstreamed in order to resolve this for other people more easily.
