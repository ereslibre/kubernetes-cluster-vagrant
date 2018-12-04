.PHONY: all
all: up kubeconfig

.PHONY: base-box
base-box:
	$(MAKE) -C $@

.PHONY: up
up: base-box
	vagrant up

.PHONY: kubeadm
kubeadm:
	PACKAGES=kubeadm vagrant provision

.PHONY: kubeconfig
kubeconfig:
	@mkdir -p ~/.kube
	@vagrant ssh $(shell ruby -I vagrant -r utils -e 'print cluster.init_master.full_name') -c 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config 2>/dev/null
	@echo ">>> kubeconfig written to $(HOME)/.kube/config"

.PHONY: reset
reset:
	@ruby -I vagrant -r utils -e 'print cluster.cluster_machines.map(&:full_name).join("\n")' | xargs -I{} vagrant ssh {} -c "sudo kubeadm reset -f"
	@rm -rf ~/.kube

.PHONY: destroy
destroy:
	vagrant destroy -f

.PHONY: clean
clean: destroy
	@ruby -I vagrant -r utils -e 'print cluster.name' | xargs -I{} rm -rf tmp/{}
	@rm -rf ~/.kube
