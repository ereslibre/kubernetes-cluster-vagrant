KUBEPATH = $(GOPATH)/src/k8s.io/kubernetes
KUBERNETES_BUILD_CONTAINER = docker ps --filter=name=kubernetes-build -q

.PHONY: all
all: up kubeconfig

.PHONY: base-box
base-box:
	$(MAKE) -C $@

.PHONY: up
up: base-box
	vagrant up

.PHONY: kubeconfig
kubeconfig:
	@mkdir -p ~/.kube
	@vagrant ssh $(shell ruby -I vagrant -r utils -e 'print cluster.init_master.full_name') -c 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config 2>/dev/null
	@echo ">>> kubeconfig written to $(HOME)/.kube/config"

.PHONY: reset
reset:
	@ruby -I vagrant -r utils -e 'print cluster.cluster_machines.map(&:full_name).join("\n")' | xargs -I{} vagrant ssh {} -c "sudo kubeadm reset -f"
	@rm -rf ~/.kube

.PHONY: run
run:
	$(MAKE) -C kubernetes-build
	-@kubernetes-build/scripts/start-container.sh &> /dev/null

.PHONY: debs
debs: run
	docker exec -it $(shell $(KUBERNETES_BUILD_CONTAINER)) su -c "cd $(KUBEPATH) && bazel build //build/debs" - $(shell id -u -n)

.PHONY: images
images: run
	docker exec -it $(shell $(KUBERNETES_BUILD_CONTAINER)) su -c "cd $(KUBEPATH) && bazel build //build:docker-artifacts" - $(shell id -u -n)

.PHONY: artifacts
artifacts: debs images

.PHONY: shell
shell: run
	docker exec -it $(shell $(KUBERNETES_BUILD_CONTAINER)) su -c "cd $(KUBEPATH) && bash" - $(shell id -u -n)

.PHONY: destroy
destroy:
	@vagrant destroy -f &> /dev/null || true

.PHONY: clean
clean: destroy
	@docker rm -f kubernetes-build &> /dev/null || true
	@ruby -I vagrant -r utils -e 'print cluster.name' 2> /dev/null | xargs -I{} rm -rf tmp/{} || true
	@rm -rf ~/.kube &> /dev/null || true
