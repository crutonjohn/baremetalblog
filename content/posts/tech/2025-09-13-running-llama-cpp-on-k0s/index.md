---
title: Running ollama on k0s
description: "Working around Nvidia's shortcomings to get a GPU inside Ollama"
summary: ""
date: 2025-09-13
draft: false
toc: true
images:
categories:
  - tech
tags:
  - llm
  - ai
  - k8s
---

# Foreward about LLM Culture

I've been intrigued by the AI and LLM mindvirus that seems to have infected the whole world. I won't lament about the moral, ethical, or environmental impacts that come along with commercialized Artificial Intelligence (although I could). The reality is that Pandora's Box has been opened, and the curse upon mankind has percolated through every facet of human existence.

Anyways, here's how I deployed ollama on k0s using an Nvidia RTX 3080. It could probably work for other k8s distributions if you tweak a few things.

# Installation

## Quick note about Consumer vs Enterprise hardware

If you're going to go through with running a consumer GPU in your cluster just know that it is not supported by many of the upstream Nvidia documentation or helm charts. For example, their [gpu-operator]() handles probably 90% of this stuff for you, including installing the drivers, the container toolkit, etc. _However_ **none of that works for consumer GPUs**, at least for me it didn't. I tried to go the official way, even going so far as to hack away at the primitives in the helm-chart to get things kickstarted. Every time the gpu-operator prints:

```
{"level":"info","ts":1758250136.8297,"logger":"controllers.ClusterPolicy","msg":"No GPU node in the cluster, do not create DaemonSets ","DaemonSet":"nvidia-mig-manager","Namespace":"kube-system"}
```

I'd suggest avoiding deploying it entirely unless you have a datacenter GPU. There may yet be a way to get this working with a fair bit of hacking but I gave up on it because Nvidia just refuses to acknowledge these use cases. Which is fine. It's precisely why I opted to buy a 9070 XT for my gaming desktop.

## Context of my environment

- OS: Mix of Debian 12 and Debian 13
- k8s Distro: k0s
- 3 dedicated control plane nodes
- 4 total worker nodes
- 1 RTX 3080

## Setting up your GPU Node

### Install the Nvidia GPU Driver

This one is pretty straightforward. You need to navigate to [the Nvidia driver download site](https://www.nvidia.com/en-us/drivers/) and use the filters to find the driver for your GPU. I'd suggest the latest, as that is what ollama suggests in their troubleshooting guide.

Once you search for and find the list of drivers, you can right click the "Download" button and copy the link. It should look something like this:

```
https://us.download.nvidia.com/XFree86/Linux-x86_64/580.82.09/NVIDIA-Linux-x86_64-580.82.09.run
```

SSH to the node that has the GPU, and `curl` the download:

```bash
curl -O -L https://us.download.nvidia.com/XFree86/Linux-x86_64/580.82.09/NVIDIA-Linux-x86_64-580.82.09.run
```

Next you simply execute the installation with `sh` (as per the documentation):

```bash
sh ./NVIDIA-Linux-x86_64-580.82.09.run
```

This executes a nice little interactive TUI. Just follow the prompts. If you aren't running X11/Wayland (you're running this on a headless server right?) then don't bother installing or configuring the stuff for X.


### Install the Nvidia Container Toolkit

You also need to install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). As always, check upstream docs first, but I'll recap what I did here if it maybe saves you a click.

I created this bash script that condenses all their steps into one:

```bash
NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

sudo apt-get install -y \
    nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
```

After you run all of that, you should be able to run:

```bash
root@fulgrim:~# nvidia-ctk --help
NAME:
   NVIDIA Container Toolkit CLI - Tools to configure the NVIDIA Container Toolkit

USAGE:
   NVIDIA Container Toolkit CLI [global options] command [command options]

VERSION:
   1.17.8
commit: f202b80a9b9d0db00d9b1d73c0128c8962c55f4d

COMMANDS:
   hook     A collection of hooks that may be injected into an OCI spec
   runtime  A collection of runtime-related utilities for the NVIDIA Container Toolkit
   info     Provide information about the system
   cdi      Provide tools for interacting with Container Device Interface specifications
   system   A collection of system-related utilities for the NVIDIA Container Toolkit
   config   Interact with the NVIDIA Container Toolkit configuration
   help, h  Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug, -d    Enable debug-level logging (default: false) [$NVIDIA_CTK_DEBUG]
   --quiet        Suppress all output except for errors; overrides --debug (default: false) [$NVIDIA_CTK_QUIET]
   --help, -h     show help
   --version, -v  print the version
```

### Configuring k0s' containerd Runtime

#### Info Gathering

As you may or may not know, k0s ships it's own bundled containerd runtime. This means that configuring containerd may be slightly different than normal. According to the [Nvidia documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuring-containerd-for-kubernetes) you could run a single command `sudo nvidia-ctk runtime configure --runtime=containerd`. However, I don't find that very helpful because I don't know what exactly it is doing. So in my case I opted to do things a little more manually.

If you look into the k0s documentation regarding [configuring containerd](https://docs.k0sproject.io/v1.33.4+k0s.0/runtime/), they state:

> In order to make changes to containerd configuration first you need to generate a default containerd configuration by running: `containerd config default > /etc/k0s/containerd.toml`

However, in my case this file already existed:

```bash
root@fulgrim:~# cat /etc/k0s/containerd.toml
# k0s_managed=true
# This is a placeholder configuration for k0s managed containerd.
# If you wish to override the config, remove the first line and replace this file with your custom configuration.
# For reference see https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md
version = 2
imports = [
	"/run/k0s/containerd-cri.toml",
]
```

Sweet, so we have the ability to extend the k0s containerd config natively. Nvidia also provides us a way to deploy their desired containerd config updates:

```
root@fulgrim:~# nvidia-ctk --quiet runtime configure --runtime=containerd --dry-run
version = 2

[plugins]

  [plugins."io.containerd.grpc.v1.cri"]

    [plugins."io.containerd.grpc.v1.cri".containerd]

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "/usr/bin/nvidia-container-runtime"
```

### Implementing the Changes

There's probably another more creative way to do this, but this is what I settled on. We can copy the contents of `/run/k0s/containerd-cri.toml` to a new file in `/etc/k0s/`, then apply the config changes using `nvidia-ctk`. After that we just point `/etc/k0s/containerd.toml` at our new file.

First we copy the running config to a new file:

```bash
cat /run/k0s/containerd-cri.toml > /etc/k0s/containerd-cri.toml
```

Let `nvidia-ctk` do its thing:

```bash
nvidia-ctk runtime configure --runtime=containerd /etc/k0s/containerd-cri.toml
```

Following the directions in the aforementioned `/etc/k0s/containerd.toml` we can replace the previous running config with our newly created `/etc/k0s/containerd-cri.toml`. Make sure you remove the top line that has `k0s_managed=true` to prevent k0s from overwriting our changes:

```
# This is a placeholder configuration for k0s managed containerd.
# If you wish to override the config, remove the first line and replace this file with your custom configuration.
# For reference see https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md
version = 2
imports = [
	#"/run/k0s/containerd-cri.toml",
    "/etc/k0s/containerd-cri.toml",
]
```

Now we just restart k0sworker.service:

```bash
systemctl restart k0sworker.service
```

## Configuring kubernetes

### Pre-Reqs

Now we can deploy the [nvidia-device-plugin](https://github.com/NVIDIA/k8s-device-plugin). Essentially this little guy informs your kublet that there is a GPU resource on one (or more) nodes that can be allocated/reserved by a running pod.

#### Supporting Resources Stolen from gpu-operator

Although I mentioned before that the Nvidia gpu-operator is basically useless for consumer GPUs, there happens to be a few small things that we need from it. Fret not, as we don't have to deploy the entire helm chart to get it.

##### RuntimeClass

We need a `RuntimeClass` that defines a new class for `nvidia`. You can go ahead and apply this to your cluster (`RuntimeClass` is cluster-scoped):

```yaml
apiVersion: node.k8s.io/v1
handler: nvidia
kind: RuntimeClass
metadata:
  labels:
    app.kubernetes.io/component: gpu-operator
  name: nvidia
```

Clearly mine is a remnant from my failed gpu-operator tinkering. Not sure if the label is required, but I left it for completeness.

##### Labeling Nodes

Additionally, if you are already running [node-feature-discovery](https://github.com/kubernetes-sigs/node-feature-discovery) you can deploy some `nodeFeatureRules` to help nvidia-device-plugin scheduling. These essentially add labels to your node(s) based on their attached PCIe device, in this case a GPU. In my case I have a 3080. We can find the PCIe bus information by using `lspci`:

```bash
root@fulgrim:~# lspci -nn | grep -i nvidia | grep VGA
c1:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
```

The values we're looking for here are `10de:2206`, indicating the vendor `10de` and the device `2206`. Using that we can create our own NFD `nodeFeatureRule`. This is kind of an exercise for the reader, but I'll provide my `nodeFeatureRule` as an example:

```yaml
apiVersion: nfd.k8s-sigs.io/v1alpha1
kind: NodeFeatureRule
metadata:
  name: nvidia-nfd-nodefeaturerules
spec:
  rules:
  - labels:
      nvidia.com/gpu.RTX3080.pcie: "true"
      nvidia.com/gpu.family: "ampere"
      feature.node.kubernetes.io/nvidia-gpu: "3080"
      nvidia.com/gpu.present: "true"
    matchFeatures:
    - feature: pci.device
      matchExpressions:
        device:
          op: In
          value:
          - "2206"
        vendor:
          op: In
          value:
          - 10de
    name: NVIDIA RTX3080
```

The labels you apply aren't really required to be in that exact format, but I simply just emulated what the `gpu-operator` would apply. If you aren't running node-feature-discovery then you can simply label your GPU-laden node the old fashioned way.

```bash
kubectl label node <your-nodes-name> nvidia.com/gpu.RTX3080.pcie=true
```

### nvidia-device-plugin

You can essentially deploy the nvidia-device-plugin wholesale, however there is one gotcha that you should pay attention to. Within the [helm chart values](https://github.com/NVIDIA/k8s-device-plugin/blob/af276bfa4be954f6ac7534cc01891a3a7dcb436f/deployments/helm/nvidia-device-plugin/values.yaml) there is some [pre-defined node affinity stuff](https://github.com/NVIDIA/k8s-device-plugin/blob/af276bfa4be954f6ac7534cc01891a3a7dcb436f/deployments/helm/nvidia-device-plugin/values.yaml#L63-L84):

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        # On discrete-GPU based systems NFD adds the following label where 10de is the NVIDIA PCI vendor ID
        - key: feature.node.kubernetes.io/pci-10de.present
          operator: In
          values:
          - "true"
      - matchExpressions:
        # On some Tegra-based systems NFD detects the CPU vendor ID as NVIDIA
        - key: feature.node.kubernetes.io/cpu-model.vendor_id
          operator: In
          values:
          - "NVIDIA"
      - matchExpressions:
        # We allow a GPU deployment to be forced by setting the following label to "true"
        - key: "nvidia.com/gpu.present"
          operator: In
          values:
          - "true"
```

You'll want to make sure that these labels match whatever is in your `nodefeaturerule` or your manually applied labels. You could probably also just skip all the labeling nonsense and just lock it to a `nodeSelector` but I haven't tested that personally.

Once youve deployed nvidia-device-plugin via helm or otherwise, we can check the logs to make sure things are working:

```bash
kubectl logs -l app.kubernetes.io/instance=nvidia-device-plugin


I0918 03:24:53.991797       1 main.go:235] "Starting NVIDIA Device Plugin" version=<
	3c378193
	commit: 3c378193fcebf6e955f0d65bd6f2aeed099ad8ea
 >
I0918 03:24:53.991843       1 main.go:238] Starting FS watcher for /var/lib/kubelet/device-plugins
I0918 03:24:53.991884       1 main.go:245] Starting OS watcher.
I0918 03:24:53.992196       1 main.go:260] Starting Plugins.
I0918 03:24:53.992231       1 main.go:317] Loading configuration.
I0918 03:24:53.993192       1 main.go:342] Updating config with default resource matching patterns.
I0918 03:24:53.993401       1 main.go:353]
Running with config:
{
  "version": "v1",
  "flags": {
    "migStrategy": "none",
    "failOnInitError": true,
    "mpsRoot": "/run/nvidia/mps",
    "nvidiaDriverRoot": "/",
    "nvidiaDevRoot": "/",
    "gdsEnabled": false,
    "mofedEnabled": false,
    "useNodeFeatureAPI": null,
    "deviceDiscoveryStrategy": "auto",
    "plugin": {
      "passDeviceSpecs": false,
      "deviceListStrategy": [
        "envvar"
      ],
      "deviceIDStrategy": "uuid",
      "cdiAnnotationPrefix": "cdi.k8s.io/",
      "nvidiaCTKPath": "/usr/bin/nvidia-ctk",
      "containerDriverRoot": "/driver-root"
    }
  },
  "resources": {
    "gpus": [
      {
        "pattern": "*",
        "name": "nvidia.com/gpu"
      }
    ]
  },
  "sharing": {
    "timeSlicing": {}
  },
  "imex": {}
}
I0918 03:24:53.993408       1 main.go:356] Retrieving plugins.
I0918 03:24:55.884566       1 server.go:195] Starting GRPC server for 'nvidia.com/gpu'
I0918 03:24:55.885835       1 server.go:139] Starting to serve 'nvidia.com/gpu' on /var/lib/kubelet/device-plugins/nvidia-gpu.sock
I0918 03:24:55.888285       1 server.go:146] Registered device plugin for 'nvidia.com/gpu' with Kubelet
```

This is the desired output. Specifically `Registered device plugin for 'nvidia.com/gpu' with Kubelet`. This means we can request the GPU to be attached to a pod.


### Ollama

This won't be a comprehensive guide on how to deploy Ollama. Using helm we will simply just make sure the following values are present:

```yaml
ollama:
  gpu:
    enabled: true
    number: 1
    nvidiaResource: nvidia.com/gpu
    type: nvidia
runtimeClassName: "nvidia"
```

More generally speaking, you can request a GPU by adding `nvidia.com/gpu: "1"` in the resources block of any Deployment or Pod, and setting the `runtimeClassName`. This example is an excerpt from my ollama deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
spec:
  ...
  template:
    spec:
      ...
      containers:
        ...
        resources:
          limits:
            cpu: "4"
            memory: 8Gi
            nvidia.com/gpu: "1"
          requests:
            cpu: "2"
            memory: 4Gi
      ...
      runtimeClassName: nvidia
```

# Further Reading

- [My repo source for installing nvidia-device-plugin](https://github.com/crutonjohn/gitops/blob/15e24e8baf9a30ae71c8f249ba62f5c2d860f8c9/clusters/core/env/production/kube-system/nvidia-device-plugin/app/hr.yaml)
- [My repo source for installing ollama](https://github.com/crutonjohn/gitops/blob/15e24e8baf9a30ae71c8f249ba62f5c2d860f8c9/clusters/apps/env/production/home/ollama/app/hr.yaml)
