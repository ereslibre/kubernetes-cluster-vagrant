KUBEPATH = $(GOPATH)/src/k8s.io/kubernetes
KUBERNETES_BUILD_CONTAINER = docker ps --filter=name=kubernetes-build -q

.PHONY: all
all: up instructions kubeconfig

.PHONY: base-box
base-box:
	$(MAKE) -C $@

.PHONY: up
up: base-box
	vagrant up

.PHONY: kubeconfig
kubeconfig:
	@scripts/fetch-kubeconfig.sh

.PHONY: instructions
instructions:
	@ruby -I vagrant -r utils -e 'cluster.instructions' 2> /dev/null

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

.PHONY: bazel
bazel: run
	docker exec -it $(shell $(KUBERNETES_BUILD_CONTAINER)) su -c "cd $(KUBEPATH) && bazel $(WHAT)" - $(shell id -u -n)

.PHONY: destroy
destroy:
	@vagrant destroy -f &> /dev/null || true
	@ruby -I vagrant -r utils -e 'print cluster.name' 2> /dev/null | xargs -I{} rm -rf tmp/{} || true
	@rm -rf ~/.kube &> /dev/null || true

.PHONY: clean
clean: destroy
	@docker rm -f -v kubernetes-build &> /dev/null || true

.PHONY: kubeadm-e2e
kubeadm-e2e:
	$(MAKE) bazel WHAT="build //vendor/github.com/onsi/ginkgo/ginkgo //test/e2e_kubeadm:e2e_kubeadm.test"
	KUBECONFIG=$(HOME)/.kube/config $(KUBEPATH)/bazel-bin/test/e2e_kubeadm/e2e_kubeadm.test

.PHONY: full-clean
full-clean: clean
	$(MAKE) -C base-box clean
	$(MAKE) -C kubernetes-build clean
