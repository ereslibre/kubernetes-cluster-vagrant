# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'fileutils'
require File.join(File.dirname(__FILE__), 'vagrant', 'utils')

check_profile

if provisioning?
  check_kubernetes
  check_packages packages
  check_images images
end

if cluster.ha?
  FileUtils.mkdir_p File.join(File.dirname(__FILE__), 'tmp', cluster.name)
end

Vagrant.configure("2") do |config|
  cluster.machines.each do |machine|
    config.vm.define machine.full_name do |vm_config|
      vm_config.vm.box = "kubernetes-vagrant"

      vm_config.vm.hostname = machine.name

      vm_config.vm.network "private_network", ip: machine.ip

      # On the "init master" machine, mount `/vagrant`, so we can transfer the
      # secrets for the HA clusters to the remaining masters.
      if !cluster.ha? || !machine.init_master?
        vm_config.vm.synced_folder ".", "/vagrant", disabled: true
      elsif machine.init_master?
        vm_config.vm.synced_folder "tmp/#{cluster.name}", "/vagrant"
      end

      vm_config.vm.provider "virtualbox" do |vb|
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
        vb.linked_clone = true
      end

      case machine.role
      when "loadbalancer"
        vm_config.vm.provision :file, source: template_file("configs/haproxy.config.erb", binding), destination: "/tmp/haproxy.cfg"
        vm_config.vm.provision :shell, inline: "mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg; systemctl enable haproxy; systemctl restart haproxy"
      when "master", "worker"
        if cluster.ha? && machine.master? && !machine.init_master?
          vm_config.vm.provision :file, source: "tmp/#{cluster.name}", destination: "/tmp/kubernetes"
        end

        # Install specific packages if provided
        packages.each do |package|
          vm_config.vm.provision :file, source: package_path(package), destination: kubernetes_target_path("#{package}.deb")
        end

        # Install specific container images if provided
        images.each do |image|
          vm_config.vm.provision :file, source: image_path(image), destination: kubernetes_target_path("#{image}.tar")
        end

        # Perform the packages and container images installation
        unless packages.empty? && images.empty?
          vm_config.vm.provision :shell, inline: template("scripts/install.erb", binding)
        end

        # Install specific manifests if provided
        if machine.init_master?
          manifests(cluster).each do |manifest|
            vm_config.vm.provision :file, source: template_file("manifests/#{manifest}.yaml.erb", binding), destination: manifests_config_target_path("#{manifest}.yaml")
          end
        end

        if machine.master? && up?
          vm_config.vm.provision :file, source: template_file("configs/default.config.erb", binding), destination: kubeadm_config_target_path("default.config")
        end

        if cluster.bootstrap && up?
          vm_config.vm.provision :shell, inline: template("scripts/bootstrap.erb", binding), privileged: false
        end
      else
        raise "Unknown machine role: #{machine.role} on machine #{machine.name}"
      end
    end
  end
end
