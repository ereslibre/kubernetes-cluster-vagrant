# -*- mode: ruby -*-
# vi: set ft=ruby :

require File.join(File.dirname(__FILE__), 'vagrant', 'utils')

check_profile

if provisioning?
  check_kubernetes
  check_packages packages
  check_images images
end

Vagrant.configure("2") do |config|
  cluster.machines.each do |machine|
    config.vm.define machine.full_name do |vm_config|
      vm_config.vm.box = "kubernetes-vagrant"

      vm_config.vm.hostname = machine.name

      vm_config.vm.network :private_network, ip: machine.ip
      vm_config.vm.synced_folder ".", "/vagrant", disabled: true

      vm_config.vm.provider "virtualbox" do |vb|
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
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
      manifests(cluster).each do |manifest|
        vm_config.vm.provision :file, source: template_file("manifests/#{manifest}.yaml.erb", binding), destination: manifests_config_target_path("#{manifest}.yaml")
      end

      if machine.init_master? && up?
        vm_config.vm.provision :file, source: template_file("configs/default.config.erb", binding), destination: kubeadm_config_target_path("default.config")
      end

      if cluster.bootstrap && up?
        vm_config.vm.provision :shell, inline: template("scripts/bootstrap.erb", binding), privileged: false
      end
    end
  end
end
