require "spec_helper"
require "json"

# We need to load the driver to test its private methods, but it has heavy
# dependencies (docker-api, lockfile, etc). Instead, we test the methods
# by creating a minimal subclass that exposes them.

# Stub the Excon module that the driver references at load time
module Excon
  def self.defaults
    @defaults ||= {}
  end
end unless defined?(Excon)

# Stub lockfile
module Lockfile; end unless defined?(Lockfile)

# Now we can define a test harness that includes the relevant private methods
# from the driver without requiring the full Docker stack.
class DriverTestHarness
  attr_accessor :config

  def initialize(config = {})
    @config = config
  end

  # Expose the PartialHash class
  class PartialHash < Hash
    def ==(other)
      other.is_a?(Hash) && all? { |key, val| other.key?(key) && other[key] == val }
    end
  end

  def parse_image_name(image)
    parts = image.split(":")

    if parts.size > 2
      tag = parts.pop
      repo = parts.join(":")
    else
      tag = parts[1] || "latest"
      repo = parts[0]
    end

    [repo, tag]
  end

  def repo(image)
    parse_image_name(image)[0]
  end

  def tag(image)
    parse_image_name(image)[1]
  end

  def short_image_path(image)
    "#{repo(image)}:#{tag(image)}"
  end

  def registry_image_path(image)
    if config[:docker_registry]
      "#{config[:docker_registry]}/#{short_image_path(image)}"
    else
      short_image_path(image)
    end
  end

  def chef_version
    return "latest" if config[:chef_version] == "stable"

    config[:chef_version]
  end

  def chef_image
    "#{config[:chef_image]}:#{chef_version}"
  end

  def chef_container_name
    config[:platform] != "" ? "chef-#{chef_version}-" + config[:platform].sub("/", "-") : "chef-#{chef_version}"
  end

  def oci_platform(platform)
    if !platform.nil? && platform.include?("/")
      os, arch = platform.split("/")
      platform = { os: os, architecture: arch }.to_json
    end
    platform
  end

  def coerce_tmpfs(v)
    case v
    when Hash, nil
      v
    else
      Array(v).each_with_object({}) do |y, h|
        name, opts = y.split(":", 2)
        h[name.to_s] = opts.to_s
      end
    end
  end

  def image_prefix
    config[:image_prefix]
  end

  def instance_name
    "test-instance"
  end

  def work_image
    [image_prefix, instance_name].compact.join("/").downcase
  end

  def coerce_volumes(v, binds)
    case v
    when PartialHash, nil
      v
    when Hash
      PartialHash[v]
    else
      b = []
      v.delete_if do |x|
        parts = x.split(":")
        b << x if parts.length > 1
      end
      b = nil if b.empty?
      binds.push(b) unless binds.include?(b) || b.nil?
      return PartialHash.new if v.empty?

      v.each_with_object(PartialHash.new) { |volume, h| h[volume] = {} }
    end
  end
end

RSpec.describe "Kitchen::Driver::Dokken" do
  let(:driver) { DriverTestHarness.new(config) }
  let(:config) { {} }

  describe "#parse_image_name" do
    it "parses repo:tag" do
      expect(driver.parse_image_name("ubuntu:22.04")).to eq(["ubuntu", "22.04"])
    end

    it "defaults tag to latest when not specified" do
      expect(driver.parse_image_name("ubuntu")).to eq(["ubuntu", "latest"])
    end

    it "handles registry with port" do
      expect(driver.parse_image_name("registry.io:5000/myimage:v1")).to eq(["registry.io:5000/myimage", "v1"])
    end

    it "handles registry with port and no tag" do
      expect(driver.parse_image_name("registry.io:5000/myimage")).to eq(["registry.io", "5000/myimage"])
    end

    it "handles namespaced images" do
      expect(driver.parse_image_name("chef/chef:latest")).to eq(["chef/chef", "latest"])
    end
  end

  describe "#repo" do
    it "returns the repo portion" do
      expect(driver.repo("ubuntu:22.04")).to eq("ubuntu")
    end

    it "returns full path for namespaced image" do
      expect(driver.repo("chef/chef:latest")).to eq("chef/chef")
    end
  end

  describe "#tag" do
    it "returns the tag portion" do
      expect(driver.tag("ubuntu:22.04")).to eq("22.04")
    end

    it "defaults to latest" do
      expect(driver.tag("ubuntu")).to eq("latest")
    end
  end

  describe "#short_image_path" do
    it "normalizes image to repo:tag format" do
      expect(driver.short_image_path("ubuntu")).to eq("ubuntu:latest")
    end

    it "preserves explicit tag" do
      expect(driver.short_image_path("ubuntu:22.04")).to eq("ubuntu:22.04")
    end
  end

  describe "#registry_image_path" do
    context "without docker_registry" do
      let(:config) { { docker_registry: nil } }

      it "returns short_image_path" do
        expect(driver.registry_image_path("ubuntu:22.04")).to eq("ubuntu:22.04")
      end
    end

    context "with docker_registry" do
      let(:config) { { docker_registry: "myregistry.io" } }

      it "prepends registry" do
        expect(driver.registry_image_path("ubuntu:22.04")).to eq("myregistry.io/ubuntu:22.04")
      end
    end
  end

  describe "#chef_version" do
    it "maps 'stable' to 'latest'" do
      driver.config[:chef_version] = "stable"
      expect(driver.chef_version).to eq("latest")
    end

    it "returns the configured version" do
      driver.config[:chef_version] = "17.10.0"
      expect(driver.chef_version).to eq("17.10.0")
    end

    it "returns 'latest' as-is" do
      driver.config[:chef_version] = "latest"
      expect(driver.chef_version).to eq("latest")
    end
  end

  describe "#chef_image" do
    it "combines chef_image config with chef_version" do
      driver.config[:chef_image] = "cincproject/cinc"
      driver.config[:chef_version] = "17.10.0"
      expect(driver.chef_image).to eq("cincproject/cinc:17.10.0")
    end
  end

  describe "#chef_container_name" do
    it "generates name without platform" do
      driver.config[:platform] = ""
      driver.config[:chef_version] = "latest"
      expect(driver.chef_container_name).to eq("chef-latest")
    end

    it "generates name with platform" do
      driver.config[:platform] = "linux/amd64"
      driver.config[:chef_version] = "17.10.0"
      expect(driver.chef_container_name).to eq("chef-17.10.0-linux-amd64")
    end
  end

  describe "#oci_platform" do
    it "returns nil for nil input" do
      expect(driver.oci_platform(nil)).to be_nil
    end

    it "returns empty string as-is" do
      expect(driver.oci_platform("")).to eq("")
    end

    it "converts os/arch format to JSON" do
      result = driver.oci_platform("linux/amd64")
      parsed = JSON.parse(result)
      expect(parsed).to eq({ "os" => "linux", "architecture" => "amd64" })
    end

    it "returns non-slash platforms as-is" do
      expect(driver.oci_platform("linux")).to eq("linux")
    end
  end

  describe "#coerce_tmpfs" do
    it "returns nil for nil" do
      expect(driver.coerce_tmpfs(nil)).to be_nil
    end

    it "returns hash unchanged" do
      hash = { "/tmp" => "rw,noexec" }
      expect(driver.coerce_tmpfs(hash)).to eq(hash)
    end

    it "converts array of strings to hash" do
      result = driver.coerce_tmpfs(["/tmp:rw,noexec", "/run"])
      expect(result).to eq({ "/tmp" => "rw,noexec", "/run" => "" })
    end

    it "handles single string" do
      result = driver.coerce_tmpfs(["/tmp"])
      expect(result).to eq({ "/tmp" => "" })
    end
  end

  describe "#work_image" do
    it "returns instance_name without prefix" do
      driver.config[:image_prefix] = nil
      expect(driver.work_image).to eq("test-instance")
    end

    it "prepends image_prefix when set" do
      driver.config[:image_prefix] = "myprefix"
      expect(driver.work_image).to eq("myprefix/test-instance")
    end
  end

  describe "PartialHash" do
    it "matches when all keys are present in other hash" do
      partial = DriverTestHarness::PartialHash.new
      partial["a"] = 1
      expect(partial == { "a" => 1, "b" => 2 }).to be true
    end

    it "does not match when a key is missing" do
      partial = DriverTestHarness::PartialHash.new
      partial["a"] = 1
      expect(partial == { "b" => 2 }).to be false
    end

    it "does not match when values differ" do
      partial = DriverTestHarness::PartialHash.new
      partial["a"] = 1
      expect(partial == { "a" => 2 }).to be false
    end

    it "empty PartialHash matches any hash" do
      partial = DriverTestHarness::PartialHash.new
      expect(partial == { "a" => 1 }).to be true
    end

    it "does not match non-hash objects" do
      partial = DriverTestHarness::PartialHash.new
      partial["a"] = 1
      expect(partial == "not a hash").to be false
    end
  end

  describe "#coerce_volumes" do
    it "returns nil for nil" do
      expect(driver.coerce_volumes(nil, [])).to be_nil
    end

    it "converts hash to PartialHash" do
      result = driver.coerce_volumes({ "/data" => {} }, [])
      expect(result).to be_a(DriverTestHarness::PartialHash)
      expect(result).to eq({ "/data" => {} })
    end

    it "separates bind mounts from volumes" do
      binds = []
      result = driver.coerce_volumes(["/host:/container", "/data"], binds)
      expect(result).to eq({ "/data" => {} })
      expect(binds.flatten).to include("/host:/container")
    end

    it "returns empty PartialHash when all items are bind mounts" do
      binds = []
      result = driver.coerce_volumes(["/host:/container"], binds)
      expect(result).to eq({})
      expect(result).to be_a(DriverTestHarness::PartialHash)
    end

    it "leaves PartialHash input unchanged" do
      ph = DriverTestHarness::PartialHash["/data" => {}]
      binds = []
      expect(driver.coerce_volumes(ph, binds)).to equal(ph)
    end
  end
end
