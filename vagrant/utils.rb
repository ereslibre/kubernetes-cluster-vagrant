require 'erb'
require 'json'
require 'tempfile'

CLUSTER_SIZE = ENV["CLUSTER_SIZE"] || 3
PACKAGES = %w(cri-tools kubeadm kubectl kubelet kubernetes-cni)
IMAGES = %w(kube-apiserver kube-controller-manager kube-proxy kube-scheduler)
MANIFESTS = %w(flannel)
CONTAINER_IMAGES = JSON.parse File.read(File.join(File.dirname(__FILE__), '..', 'base-box', 'configs', 'container_images.json')), symbolize_names: true
EXTRA_CONTAINER_IMAGES = JSON.parse(File.read(File.join(File.dirname(__FILE__), '..', 'base-box', 'configs', 'extra_container_images.json')), symbolize_names: true) rescue {}
KUBERNETES_PATH = "#{ENV["GOPATH"]}/src/k8s.io/kubernetes"

class KubernetesNetwork
  attr_accessor :pod_subnet, :service_subnet

  def initialize(pod_subnet:, service_subnet:)
    @pod_subnet, @service_subnet = pod_subnet, service_subnet
  end
end

class KubernetesCluster
  attr_accessor :name, :token, :bootstrap, :machines, :network

  def initialize(name:, token:, bootstrap:)
    @name, @token, @bootstrap = name, token, bootstrap
  end

  def init_master
    masters.first
  end

  def lb
    @machines.find { |machine| machine.lb? }
  end

  def masters
    @machines.select { |machine| machine.master? }
  end

  def cluster_machines
    @machines.select { |machine| !machine.lb? }
  end

  def ha?
    masters.length > 1
  end
end

class KubernetesMachine
  attr_accessor :cluster, :name, :role, :ip
  alias advertise_address ip

  def initialize(cluster:, name:, role:, ip:)
    @cluster, @name, @role, @ip = cluster, name, role, ip
  end

  def lb?
    @role == "loadbalancer"
  end

  def master?
    @role == "master"
  end

  def worker?
    @role == "worker"
  end

  def init_master?
    @cluster.init_master == self
  end

  def full_name
    "#{@cluster.name}_#{@name}"
  end

  def etcd_initial_cluster_endpoints
    (@cluster.masters.take_while { |master| master != self } + [self]).map do |m|
      "#{m.name}=https://#{m.ip}:2380"
    end.join(",")
  end
end

def container_ref(name)
  unless CONTAINER_IMAGES.include?(name) || EXTRA_CONTAINER_IMAGES.include?(name)
    raise "Unknown container image: #{name}"
  end
  container_image = CONTAINER_IMAGES[name] || EXTRA_CONTAINER_IMAGES[name]
  result = ""
  if container_image[:repository] && !container_image[:repository].empty?
    result = "#{container_image[:repository]}/"
  end
  result += container_image[:name]
  if container_image[:tag] && !container_image[:tag].empty?
    result += ":#{container_image[:tag]}"
  end
  result
end

def kubernetes_path(path)
  "#{KUBERNETES_PATH}/#{path}"
end

def package_path(package)
  kubernetes_path "bazel-bin/build/debs/#{package}.deb"
end

def image_path(image)
  kubernetes_path "bazel-bin/build/#{image}.tar"
end

def full_image_version(image)
  File.read(kubernetes_path("bazel-genfiles/build/#{image}.docker_tag")).strip
end

def image_version(image)
  full_image_version(image) =~ /^([^-]+)/
  $1
end

def full_kubernetes_version
  File.read(kubernetes_path("bazel-genfiles/build/version")).strip
end

def kubernetes_version
  full_kubernetes_version =~ /^((?:\d+\.){2}\d+)/
  "v#{$1}"
end

def kubernetes_target_path(path = nil)
  if path.nil?
    "/home/vagrant/kubernetes"
  else
    "/home/vagrant/kubernetes/#{path}"
  end
end

def custom_container_image_target_path(image_path)
  File.join "/home/vagrant/custom/images", File.basename(image_path)
end

def template_file(config, b)
  template = Tempfile.new
  template.write template(config, b)
  template.rewind
  template
end

def template(config, b)
  ERB.new(File.read(config)).result(b)
end

def kubeadm_config_target_path(path)
  "/home/vagrant/kubeadm/#{path}"
end

def manifests_config_target_path(path)
  "/home/vagrant/manifests/#{path}"
end

def packages
  if ENV["PACKAGES"] == "all"
    PACKAGES
  else
    (ENV["PACKAGES"] || "").split(",")
  end
end

def images
  if ENV["IMAGES"] == "all"
    IMAGES
  else
    (ENV["IMAGES"] || "").split(",")
  end
end

def custom_container_images
  (ENV["CUSTOM_CONTAINER_IMAGES"] || "").split(",")
end

def default_manifests(cluster)
  up? ? "flannel" : ""
end

def manifests(cluster)
  if ENV["MANIFESTS"] == "all"
    MANIFESTS
  else
    (ENV["MANIFESTS"] || default_manifests(cluster)).split(",")
  end
end

def up?
  ARGV.include?("up") || (ARGV.include?("reload") && ARGV.include?("--provision"))
end

def provisioning?
  up? || ARGV.include?("provision")
end

def check_kubernetes
  raise "Kubernetes not cloned under #{KUBERNETES_PATH}; please, run `git clone git@github.com:kubernetes/kubernetes.git #{KUBERNETES_PATH}`" unless Dir.exists?(KUBERNETES_PATH)
end

def check_packages(packages)
  missing_packages = Array.new
  packages.each do |package|
    missing_packages << package unless File.exists?(package_path(package))
  end
  raise "Missing packages: #{missing_packages.join(", ")}; please, run `bazel build //build/debs` from #{KUBERNETES_PATH} or `make debs` from here" unless missing_packages.empty?
end

def check_images(images)
  missing_images = Array.new
  images.each do |image|
    missing_images << image unless File.exists?(image_path(image))
  end
  raise "Missing images: #{missing_images.join(", ")}; please, run `bazel build //build:docker-artifacts` from #{KUBERNETES_PATH} or `make images` from here" unless missing_images.empty?
end

def check_profile
  if ENV["PROFILE"].nil? || ENV["PROFILE"].empty?
    raise "Please, set PROFILE envvar to point to a JSON profile (some examples can be found inside the profiles directory)"
  end

  if !File.exists?("profiles/#{ENV["PROFILE"]}.json") && !File.exists?(ENV["PROFILE"])
    raise "Profile profiles/#{ENV["PROFILE"]}.json does not exist, and #{ENV["PROFILE"]} wasn't found either"
  end
end

def profile
  return $profile if $profile
  check_profile
  $profile = JSON.parse File.read(File.exists?(ENV["PROFILE"]) ? ENV["PROFILE"] : "profiles/#{ENV["PROFILE"]}.json"), symbolize_names: true
end

def cluster
  return $cluster if $cluster
  $cluster = KubernetesCluster.new name: profile[:cluster][:name], token: profile[:cluster][:token], bootstrap: profile[:cluster][:bootstrap]
  $cluster.network = KubernetesNetwork.new pod_subnet: profile[:cluster][:network][:pod_subnet],
                                           service_subnet: profile[:cluster][:network][:service_subnet]
  $cluster.machines = profile[:machines].map do |machine|
    KubernetesMachine.new cluster: $cluster, name: machine[:name], role: machine[:role], ip: machine[:ip]
  end.sort_by.with_index do |machine, i|
    case machine.role
    when "loadbalancer"
      [0, i]
    when "master"
      [1, i]
    when "worker"
      [2, i]
    end
  end
  $cluster
end
