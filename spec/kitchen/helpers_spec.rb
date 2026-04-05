require "spec_helper"

# Create a test harness that includes the module so we can call its methods
class HelpersTestHarness
  include Dokken::Helpers

  attr_accessor :config, :instance

  def initialize
    @config = {}
    @instance = nil
  end

  # Helpers uses self[:key] in some methods
  def [](key)
    @config[key]
  end

  # Stub logging methods
  def info(msg); end
  def debug(msg); end
end

RSpec.describe Dokken::Helpers do
  let(:harness) { HelpersTestHarness.new }

  describe "#parse_port" do
    it "parses a single port number" do
      result = harness.parse_port("8080")
      expect(result).to eq([{
        "host_ip" => "",
        "host_port" => "",
        "container_port" => "8080/tcp",
      }])
    end

    it "parses host:container format" do
      result = harness.parse_port("8080:80")
      expect(result).to eq([{
        "host_ip" => "0.0.0.0",
        "host_port" => "8080",
        "container_port" => "80/tcp",
      }])
    end

    it "parses host_ip:host_port:container_port format" do
      result = harness.parse_port("127.0.0.1:8080:80")
      expect(result).to eq([{
        "host_ip" => "127.0.0.1",
        "host_port" => "8080",
        "container_port" => "80/tcp",
      }])
    end

    it "preserves explicit protocol" do
      result = harness.parse_port("8080/udp")
      expect(result).to eq([{
        "host_ip" => "",
        "host_port" => "",
        "container_port" => "8080/udp",
      }])
    end

    it "preserves explicit protocol in host:container format" do
      result = harness.parse_port("8080:80/udp")
      expect(result).to eq([{
        "host_ip" => "0.0.0.0",
        "host_port" => "8080",
        "container_port" => "80/udp",
      }])
    end

    it "defaults to tcp protocol" do
      result = harness.parse_port("3000")
      expect(result.first["container_port"]).to eq("3000/tcp")
    end

    it "expands a port range" do
      result = harness.parse_port("8000-8002")
      expect(result.length).to eq(3)
      expect(result.map { |r| r["container_port"] }).to eq(["8000/tcp", "8001/tcp", "8002/tcp"])
    end

    it "expands a port range with protocol" do
      result = harness.parse_port("8000-8001/udp")
      expect(result.length).to eq(2)
      expect(result.map { |r| r["container_port"] }).to eq(["8000/udp", "8001/udp"])
    end

    it "handles single port range (start == end)" do
      result = harness.parse_port("8080-8080")
      expect(result.length).to eq(1)
      expect(result.first["container_port"]).to eq("8080/tcp")
    end
  end

  describe "#coerce_exposed_ports" do
    it "returns nil for nil input" do
      expect(harness.coerce_exposed_ports(nil)).to be_nil
    end

    it "returns hash input unchanged" do
      hash = { "80/tcp" => {} }
      expect(harness.coerce_exposed_ports(hash)).to eq(hash)
    end

    it "converts a single port string" do
      result = harness.coerce_exposed_ports(["80"])
      expect(result).to eq({ "80/tcp" => {} })
    end

    it "converts multiple port strings" do
      result = harness.coerce_exposed_ports(["80", "443/tcp"])
      expect(result).to eq({
        "80/tcp" => {},
        "443/tcp" => {},
      })
    end

    it "converts host:container format keeping container port" do
      result = harness.coerce_exposed_ports(["8080:80"])
      expect(result).to eq({ "80/tcp" => {} })
    end
  end

  describe "#coerce_port_bindings" do
    it "returns nil for nil input" do
      expect(harness.coerce_port_bindings(nil)).to be_nil
    end

    it "returns hash input unchanged" do
      hash = { "80/tcp" => [{ "HostIp" => "", "HostPort" => "8080" }] }
      expect(harness.coerce_port_bindings(hash)).to eq(hash)
    end

    it "converts a single port string" do
      result = harness.coerce_port_bindings(["80"])
      expect(result).to eq({
        "80/tcp" => [{ "HostIp" => "", "HostPort" => "" }],
      })
    end

    it "converts host:container format" do
      result = harness.coerce_port_bindings(["8080:80"])
      expect(result).to eq({
        "80/tcp" => [{ "HostIp" => "0.0.0.0", "HostPort" => "8080" }],
      })
    end

    it "converts ip:host:container format" do
      result = harness.coerce_port_bindings(["127.0.0.1:8080:80"])
      expect(result).to eq({
        "80/tcp" => [{ "HostIp" => "127.0.0.1", "HostPort" => "8080" }],
      })
    end

    it "groups multiple bindings for the same container port" do
      result = harness.coerce_port_bindings(["8080:80", "9090:80"])
      expect(result["80/tcp"].length).to eq(2)
      expect(result["80/tcp"]).to include(
        { "HostIp" => "0.0.0.0", "HostPort" => "8080" },
        { "HostIp" => "0.0.0.0", "HostPort" => "9090" }
      )
    end
  end

  describe ".instance_name_for" do
    it "generates a SHA-prefixed lowercase name" do
      instance = double("instance", name: "default-ubuntu-2204")
      allow(FileUtils).to receive(:pwd).and_return("/home/user/project")

      result = Dokken::Helpers.instance_name_for(instance)
      prefix = Digest::SHA2.hexdigest("/home/user/project")[0, 10]

      expect(result).to eq("#{prefix}-default-ubuntu-2204")
    end

    it "downcases the result" do
      instance = double("instance", name: "Default-Ubuntu")
      allow(FileUtils).to receive(:pwd).and_return("/tmp")

      result = Dokken::Helpers.instance_name_for(instance)
      expect(result).to eq(result.downcase)
    end

    it "produces consistent results for the same inputs" do
      instance = double("instance", name: "myinstance")
      allow(FileUtils).to receive(:pwd).and_return("/some/path")

      result1 = Dokken::Helpers.instance_name_for(instance)
      result2 = Dokken::Helpers.instance_name_for(instance)
      expect(result1).to eq(result2)
    end

    it "produces different results for different directories" do
      instance = double("instance", name: "myinstance")

      allow(FileUtils).to receive(:pwd).and_return("/path/a")
      result_a = Dokken::Helpers.instance_name_for(instance)

      allow(FileUtils).to receive(:pwd).and_return("/path/b")
      result_b = Dokken::Helpers.instance_name_for(instance)

      expect(result_a).not_to eq(result_b)
    end
  end

  describe "#instance_name" do
    it "delegates to the module method" do
      instance = double("instance", name: "test-instance")
      harness.instance = instance
      allow(FileUtils).to receive(:pwd).and_return("/test")

      expect(harness.instance_name).to eq(Dokken::Helpers.instance_name_for(instance))
    end
  end

  describe "#default_docker_host" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DOCKER_HOST").and_return(nil)
    end

    it "returns DOCKER_HOST env var when set" do
      allow(ENV).to receive(:[]).with("DOCKER_HOST").and_return("tcp://192.168.1.1:2375")
      expect(harness.default_docker_host).to eq("tcp://192.168.1.1:2375")
    end

    it "returns unix socket when /var/run/docker.sock exists" do
      allow(ENV).to receive(:[]).with("DOCKER_HOST").and_return(nil)
      allow(File).to receive(:exist?).with("/var/run/docker.sock").and_return(true)
      expect(harness.default_docker_host).to eq("unix:///var/run/docker.sock")
    end

    it "falls back to tcp://127.0.0.1:2375" do
      allow(ENV).to receive(:[]).with("DOCKER_HOST").and_return(nil)
      allow(File).to receive(:exist?).with("/var/run/docker.sock").and_return(false)
      expect(harness.default_docker_host).to eq("tcp://127.0.0.1:2375")
    end
  end

  describe "#insecure_ssh_public_key" do
    it "returns an SSH public key string" do
      expect(harness.insecure_ssh_public_key).to include("ssh-rsa")
      expect(harness.insecure_ssh_public_key).to include("test-kitchen-rsa")
    end
  end

  describe "#insecure_ssh_private_key" do
    it "returns an RSA private key" do
      expect(harness.insecure_ssh_private_key).to include("BEGIN RSA PRIVATE KEY")
      expect(harness.insecure_ssh_private_key).to include("END RSA PRIVATE KEY")
    end
  end

  describe "#running_inside_docker?" do
    it "returns true when /.dockerenv exists" do
      allow(File).to receive(:file?).with("/.dockerenv").and_return(true)
      expect(harness.running_inside_docker?).to be true
    end

    it "returns false when /.dockerenv does not exist" do
      allow(File).to receive(:file?).with("/.dockerenv").and_return(false)
      expect(harness.running_inside_docker?).to be false
    end
  end

  describe "#data_dockerfile" do
    before do
      provisioner = double("provisioner", :[] => "/opt/kitchen")
      harness.instance = double("instance", provisioner: provisioner)
    end

    it "uses almalinux:9 as default base" do
      result = harness.data_dockerfile(nil)
      expect(result).to include("FROM almalinux:9")
    end

    it "prepends registry when provided" do
      result = harness.data_dockerfile("myregistry.io")
      expect(result).to include("FROM myregistry.io/almalinux:9")
    end

    it "includes SSH server setup" do
      result = harness.data_dockerfile(nil)
      expect(result).to include("openssh-server")
      expect(result).to include("EXPOSE 22")
      expect(result).to include("sshd")
    end

    it "includes volume mounts" do
      result = harness.data_dockerfile(nil)
      expect(result).to include("VOLUME /opt/kitchen")
      expect(result).to include("VOLUME /opt/verifier")
    end
  end
end
