# kubernetes-cluster-vagrant

## What

This project intends to make it very easy to push your changes to the Kubernetes
source code into a cluster.

It uses [Vagrant](https://www.vagrantup.com/) to create the different clusters,
and allows you to have different cluster [profiles](profiles).

The idea behind this project is to create a base image that downloads all the
required dependencies. This way, it's possible to completely remove network
latency (or work completely offline if required) from your workflow.

Unit and integration tests are important and can be very helpful for many cases,
but when testing a tool like `kubeadm`, having a way to test your changes (even
if manual) can be of great help.

## Requirements

* [Virtualbox](https://www.virtualbox.org/)
* [Vagrant](https://www.vagrantup.com/)
* Kubernetes cloned under `$GOPATH/src/k8s.io/kubernetes`

## Base image

The base image will contain some general images that will be used later when
creating the cluster. These images are defined in
[`container_images.json`](base-box/configs/container_images.json). At the
moment they are:

* `coredns`
* `etcd`
* `flannel`
* `pause`

Also, the following images inside
`$GOPATH/src/k8s.io/kubernetes/_output/release-images/amd64` are also
copied and loaded in the base image:

* `kube-apiserver`
* `kube-controller-manager`
* `kube-proxy`
* `kube-scheduler`

Aside from that, the following packages inside
`$GOPATH/src/k8s.io/kubernetes/bazel-bin/build/debs` are copied and
installed in the base image too:

* `cri-tools`
* `kubeadm`
* `kubectl`
* `kubelet`
* `kubernetes-cni`

Building the base image requires internet connection for installing some
packages and the first set of containers (the ones defined in
`container_images.json`).

Once the base image is built, it is saved as a Vagrant box named
`kubernetes-vagrant`.

## Building a cluster

Building a cluster is trivial, all you need is to point to a specific profile.
Take into account that this process is completely offline and doesn't need to
download any information from the internet.

You can just run `make` with the `PROFILE` envvar set to a profile name that
exists inside the [profiles](profiles) folder, or to a full path containing
the profile you want.

```
~/p/kubernetes-cluster-vagrant (master) > env PROFILE=bootstrap/1-master-1-worker make
make -C base-box
make[1]: Entering directory '/home/ereslibre/projects/kubernetes-cluster-vagrant/base-box'
>>> Base box (kubernetes-vagrant) already exists, skipping build
make[1]: Leaving directory '/home/ereslibre/projects/kubernetes-cluster-vagrant/base-box'
vagrant up
Bringing machine 'kubernetes_master' up with 'virtualbox' provider...
Bringing machine 'kubernetes_worker' up with 'virtualbox' provider...

<snip>

>>> kubeconfig written to /home/ereslibre/.kube/config
```

After a minute or so:

```
~ > kubectl get nodes
NAME      STATUS    ROLES     AGE       VERSION
master    Ready     master    118s      v1.14.0-alpha.0.569+1e50c5711346e8-dirty
worker    Ready     <none>    60s       v1.14.0-alpha.0.569+1e50c5711346e8-dirty
```

## Deploying `kubeadm` to the cluster

Once that the cluster is running, you can build `kubeadm` on your machine and
deploy it inside the cluster using `make kubeadm`.

```
~/p/kubernetes-cluster-vagrant (master) > env PROFILE=bootstrap/1-master-1-worker make kubeadm
PACKAGES=kubeadm vagrant provision
==> kubernetes_master: Running provisioner: file...
==> kubernetes_master: Running provisioner: shell...
    kubernetes_master: Running: inline script
    kubernetes_master: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_master: Preparing to unpack .../vagrant/kubernetes/kubeadm.deb ...
    kubernetes_master: Unpacking kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_master: Setting up kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) ...
==> kubernetes_worker: Running provisioner: file...
==> kubernetes_worker: Running provisioner: shell...
    kubernetes_worker: Running: inline script
    kubernetes_worker: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_worker: Preparing to unpack .../vagrant/kubernetes/kubeadm.deb ...
    kubernetes_worker: Unpacking kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_worker: Setting up kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) ...
```

## Deploying other changes to the cluster

`vagrant provision` can be used to deploy different things to the cluster.
Everything that you want to deploy to the cluster can be controlled by
environment variables. The currently supported ones are:

* `PACKAGES`
  * `cri-tools`
  * `kubeadm`
  * `kubectl`
  * `kubelet`
  * `kubernetes-cni`
* `IMAGES`
  * `kube-apiserver`
  * `kube-controller-manager`
  * `kube-proxy`
  * `kube-scheduler`
* `MANIFESTS`
  * `flannel`

You can control what you want to deploy, and you can deploy several things at
once, for example:

```
~/p/kubernetes-cluster-vagrant (master) > env PROFILE=bootstrap/1-master-1-worker PACKAGES=kubeadm,kubelet IMAGES=kube-apiserver,kube-scheduler vagrant provision
==> kubernetes_master: Running provisioner: file...
==> kubernetes_master: Running provisioner: file...
==> kubernetes_master: Running provisioner: file...
==> kubernetes_master: Running provisioner: file...
==> kubernetes_master: Running provisioner: shell...
    kubernetes_master: Running: inline script
    kubernetes_master: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_master: Preparing to unpack .../vagrant/kubernetes/kubeadm.deb ...
    kubernetes_master: Unpacking kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_master: Setting up kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_master: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_master: Preparing to unpack .../vagrant/kubernetes/kubelet.deb ...
    kubernetes_master: Unpacking kubelet (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_master: Setting up kubelet (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_master: Loaded image: k8s.gcr.io/kube-apiserver:v1.14.0-alpha.0.569_1e50c5711346e8-dirty
    kubernetes_master: Loaded image: k8s.gcr.io/kube-scheduler:v1.14.0-alpha.0.569_1e50c5711346e8-dirty
==> kubernetes_worker: Running provisioner: file...
==> kubernetes_worker: Running provisioner: file...
==> kubernetes_worker: Running provisioner: file...
==> kubernetes_worker: Running provisioner: file...
==> kubernetes_worker: Running provisioner: shell...
    kubernetes_worker: Running: inline script
    kubernetes_worker: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_worker: Preparing to unpack .../vagrant/kubernetes/kubeadm.deb ...
    kubernetes_worker: Unpacking kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_worker: Setting up kubeadm (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_worker: (Reading database ... 60044 files and directories currently installed.)
    kubernetes_worker: Preparing to unpack .../vagrant/kubernetes/kubelet.deb ...
    kubernetes_worker: Unpacking kubelet (1.14.0~alpha.0.569+1e50c5711346e8) over (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_worker: Setting up kubelet (1.14.0~alpha.0.569+1e50c5711346e8) ...
    kubernetes_worker: Loaded image: k8s.gcr.io/kube-apiserver:v1.14.0-alpha.0.569_1e50c5711346e8-dirty
    kubernetes_worker: Loaded image: k8s.gcr.io/kube-scheduler:v1.14.0-alpha.0.569_1e50c5711346e8-dirty
```

## Destroying the cluster

```
~/p/kubernetes-cluster-vagrant (master) > env PROFILE=bootstrap/1-master-1-worker make clean
vagrant destroy -f
==> kubernetes_worker: Forcing shutdown of VM...
==> kubernetes_worker: Destroying VM and associated drives...
==> kubernetes_master: Forcing shutdown of VM...
==> kubernetes_master: Destroying VM and associated drives...
```
