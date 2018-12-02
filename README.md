# kubernetes-cluster-vagrant

## What

This project intends to make it very easy to push your changes to the Kubernetes
source code into a cluster.

It uses [Vagrant](https://www.vagrantup.com/) to create the different clusters,
and allows you to have different cluster [profiles](profiles).

The idea behind this project is to create a base box that downloads all the
required dependencies. This way, it's possible to completely remove network
latency (or work completely offline if required) from your workflow.

Both single master and multi master deployments are supported. In the multi
master deployment case, a loadbalancer will be included in the profile, that
will be the entry point to the api servers.

## Requirements

* [Virtualbox](https://www.virtualbox.org/)
* [Vagrant](https://www.vagrantup.com/)
* Kubernetes cloned under `$GOPATH/src/k8s.io/kubernetes`

## Base box

The base box will contain some general images that will be used later when
creating the cluster. These images are defined in
[`container_images.json`](base-box/configs/container_images.json). At the
moment they are:

* `coredns`
* `etcd`
* `flannel`
* `pause`

Also, the following images inside
`$GOPATH/src/k8s.io/kubernetes/_output/release-images/amd64` are also
copied and loaded in the base box:

* `kube-apiserver`
* `kube-controller-manager`
* `kube-proxy`
* `kube-scheduler`

Aside from that, the following packages inside
`$GOPATH/src/k8s.io/kubernetes/bazel-bin/build/debs` are copied and
installed in the base box too:

* `cri-tools`
* `kubeadm`
* `kubectl`
* `kubelet`
* `kubernetes-cni`

Building the base box requires internet connection for installing some packages
and the first set of containers (the ones defined in `container_images.json`).

Once the base box is built, it is saved as a Vagrant box named
`kubernetes-vagrant`.

## Building a cluster

Building a cluster is trivial, all you need is to point to a specific profile.
Take into account that this process is completely offline and doesn't need to
download any information from the internet.

You can just run `make` with the `PROFILE` envvar set to a profile name that
exists inside the [profiles](profiles) folder, or to a full path containing
the profile you want.

```
~/p/kubernetes-cluster-vagrant (master) > PROFILE=bootstrap/1-master-1-worker make
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

This will use all the versions of packages and components present in the base
box, what might not be what you are looking for.

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

It's possible to start the cluster and make it use your recently built component
versions. You just need to provide what `PACKAGES`, `IMAGES` or `MANIFESTS`
you want to be deployed when the cluster is created. For example:

```
~/p/kubernetes-cluster-vagrant (master) > PROFILE=bootstrap/1-master-1-worker PACKAGES=kubeadm,kubelet make
```

In this case, it doesn't matter what versions of `kubeadm` and `kubelet`
existed on the base box, the ones that you built on the host will be transferred
to the different cluster machines and installed as soon as the machines are up.

In the case that you are using a profile that is bootstrapping the cluster
automatically, this bootstrap will happen after the new packages have overriden
the old ones.

## Deploying changes to the cluster while it's running

`vagrant provision` can be used to deploy different things to the cluster. As
with a regular `vagrant up` (or `make`), you can also use `PACKAGES`,
`IMAGES` and `MANIFESTS` environment variables at will, to control what to
deploy.

```
~/p/kubernetes-cluster-vagrant (master) > PROFILE=bootstrap/1-master-1-worker PACKAGES=kubeadm,kubelet IMAGES=kube-apiserver,kube-scheduler vagrant provision
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

## HA deployments (multi master)

Multi master deployments are supported, and are as simple as setting the correct
profile. Example:

```
~/p/kubernetes-cluster-vagrant (master) > PROFILE=bootstrap/3-masters-1-worker make
```

This profile will create a load balancer (haproxy) that will be the entry point
for all master nodes. The `kubeconfig` file that will get generated in your
`$HOME/.kube/config` will include the reference to this load balancer IP
address.

## Destroying the cluster

You can destroy the cluster by pointing to the profile using the `PROFILE`
environment variable and calling to `make clean`. This will also clean up your
`~/.kube` folder on the host.

```
~/p/kubernetes-cluster-vagrant (master) > PROFILE=bootstrap/1-master-1-worker make clean
vagrant destroy -f
==> kubernetes_worker: Forcing shutdown of VM...
==> kubernetes_worker: Destroying VM and associated drives...
==> kubernetes_master: Forcing shutdown of VM...
==> kubernetes_master: Destroying VM and associated drives...
```

## License

```
kubernetes-cluster-vagrant
Copyright (C) 2018 Rafael Fernández López <ereslibre@ereslibre.es>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
