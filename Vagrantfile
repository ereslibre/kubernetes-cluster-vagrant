# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'fileutils'
require File.join(File.dirname(__FILE__), 'vagrant', 'utils')

MASTER_CPUS = ENV["MASTER_CPUS"].nil? ? 2 : ENV["MASTER_CPUS"].to_i
WORKER_CPUS = ENV["WORKER_CPUS"].nil? ? 2 : ENV["WORKER_CPUS"].to_i
MASTER_RAM = ENV["MASTER_RAM"].nil? ? 1024 : ENV["MASTER_RAM"].to_i
WORKER_RAM = ENV["WORKER_RAM"].nil? ? 1024 : ENV["WORKER_RAM"].to_i

check_profile

if provisioning?
  check_kubernetes
  check_packages packages
  check_images images
end

FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'tmp', cluster.name)

Vagrant.configure("2") do |config|
  cluster.machines.each do |machine|
    config.vm.define machine.full_name do |vm_config|
      vm_config.vm.box = "kubernetes-vagrant"

      vm_config.vm.hostname = machine.name

      vm_config.vm.network "private_network", ip: machine.ip

      if !machine.lb?
        vm_config.vm.synced_folder "tmp/#{cluster.name}", "/vagrant"
      end

      vm_config.vm.provider "virtualbox" do |vb|
        case machine.role
        when "master"
          vb.cpus = MASTER_CPUS
          vb.memory = MASTER_RAM
        when "worker"
          vb.cpus = WORKER_CPUS
          vb.memory = WORKER_RAM
        end
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.linked_clone = true
      end

      case machine.role
      when "loadbalancer"
        vm_config.vm.provision :file, source: template_file("configs/haproxy.config.erb", binding), destination: "/tmp/haproxy.cfg"
        vm_config.vm.provision :shell, inline: "mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg; systemctl enable haproxy; systemctl restart haproxy"
      when "master", "worker"
        # Install specific packages if provided
        packages.each do |package|
          vm_config.vm.provision :file, source: package_path(package), destination: kubernetes_target_path("#{package}.deb")
        end

        # Install specific container images if provided
        images.each do |image|
          vm_config.vm.provision :file, source: image_path(image), destination: kubernetes_target_path("#{image}.tar")
        end

        # Install custom container images (referenced by their full path in the host filesystem)
        custom_container_images.each do |image_path|
          vm_config.vm.provision :file, source: image_path, destination: custom_container_image_target_path(image_path)
        end

        # Perform the packages and container images installation
        unless packages.empty? && images.empty? && custom_container_images.empty?
          vm_config.vm.provision :shell, inline: template("scripts/install.erb", binding)
        end

        # Install specific manifests if provided
        if machine.init_master?
          manifests(cluster).each do |manifest|
            vm_config.vm.provision :file, source: template_file("manifests/#{manifest}.yaml.erb", binding), destination: manifests_config_target_path("#{manifest}.yaml")
          end
        end

        if up?
          if machine.init_master?
            vm_config.vm.provision :file, source: template_file("configs/kubeadm.config.erb", binding), destination: kubeadm_config_target_path("kubeadm.config")
          else
            vm_config.vm.provision :file, source: template_file("configs/kubeadm-join.config.erb", binding), destination: kubeadm_config_target_path("kubeadm.config")
          end

          if cluster.bootstrap
            vm_config.vm.provision :shell, inline: template("scripts/bootstrap.erb", binding), privileged: false
          else
            vm_config.vm.provision :file, source: template_file("scripts/bootstrap.erb", binding), destination: home_path("bootstrap.sh")
          end
        end
      else
        raise "Unknown machine role: #{machine.role} on machine #{machine.name}"
      end
    end
  end
end
