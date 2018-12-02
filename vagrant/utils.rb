require 'erb'
require 'json'
require 'tempfile'

CLUSTER_SIZE = ENV["CLUSTER_SIZE"] || 3
PACKAGES = %w(cri-tools kubeadm kubectl kubelet kubernetes-cni)
IMAGES = %w(kube-apiserver kube-controller-manager kube-proxy kube-scheduler)
EXTRA_IMAGES = %w(cloud-controller-manager conformance-amd64)
MANIFESTS = %w(flannel)
CONTAINER_IMAGES = JSON.parse File.read(File.join(File.dirname(__FILE__), '..', 'base-box', 'configs', 'container_images.json')), symbolize_names: true
KUBERNETES_PATH = "#{ENV["GOPATH"]}/src/k8s.io/kubernetes"

class KubernetesCluster
  attr_accessor :name, :token, :bootstrap, :machines

  def initialize(name:, token:, bootstrap:)
    @name, @token, @bootstrap = name, token, bootstrap
  end

  def init_master
    masters.first
  end

  def masters
    @machines.select { |machine| machine.master? }
  end
end

class KubernetesMachine
  attr_accessor :cluster, :name, :role, :ip
  alias advertise_address ip

  def initialize(cluster:, name:, role:, ip:)
    @cluster, @name, @role, @ip = cluster, name, role, ip
  end

  def master?
    @role == "master"
  end

  def init_master?
    @cluster.init_master == self
  end

  def full_name
    "#{@cluster.name}_#{@name}"
  end
end

def container_ref(name)
  unless CONTAINER_IMAGES.include? name
    return nil
  end
  container_image = CONTAINER_IMAGES[name]
  result = ""
  if container_image[:repository] && !container_image[:repository].empty?
    result = "#{container_image[:repository]}/"
  end
  result += container_image[:name]
  result += ":#{container_image[:tag]}"
  result
end

def kubernetes_path(path)
  "#{KUBERNETES_PATH}/#{path}"
end

def package_path(package)
  kubernetes_path "bazel-bin/build/debs/#{package}.deb"
end

def image_path(image)
  kubernetes_path "_output/release-images/amd64/#{image}.tar"
end

def full_kubernetes_version
  File.read(kubernetes_path(".dockerized-kube-version-defs")) =~ /^KUBE_GIT_VERSION='([^']+)'$/
  $1.gsub("+", "_")
end

def kubernetes_version
  File.read(kubernetes_path(".dockerized-kube-version-defs")) =~ /^KUBE_GIT_VERSION='([^-]+)/
  $1
end

def kubernetes_target_path(path = nil)
  if path.nil?
    "/home/vagrant/kubernetes"
  else
    "/home/vagrant/kubernetes/#{path}"
  end
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
  "/home/vagrant/kubeadm/config/#{path}"
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
  raise "Missing packages: #{missing_packages.join(", ")}; please, run `bazel build //build/debs` from #{KUBERNETES_PATH}" unless missing_packages.empty?
end

def check_images(images)
  missing_images = Array.new
  images.each do |image|
    missing_images << image unless File.exists?(image_path(image))
  end
  raise "Missing images: #{missing_images.join(", ")}; please, run `KUBE_BUILD_HYPERKUBE=n KUBE_BUILD_CONFORMANCE=n make quick-release-images` from #{KUBERNETES_PATH}" unless missing_images.empty?
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
  $profile ||= JSON.parse File.read(File.exists?(ENV["PROFILE"]) ? ENV["PROFILE"] : "profiles/#{ENV["PROFILE"]}.json"), symbolize_names: true
end

def cluster
  return $cluster if $cluster
  $cluster = KubernetesCluster.new name: profile[:cluster][:name], token: profile[:cluster][:token], bootstrap: profile[:cluster][:bootstrap]
  $cluster.machines = profile[:machines].map do |machine|
    KubernetesMachine.new cluster: $cluster, name: machine[:name], role: machine[:role], ip: machine[:ip]
  end
  $cluster
end
