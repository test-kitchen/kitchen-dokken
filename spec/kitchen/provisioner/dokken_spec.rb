require "spec_helper"

# Test harness that replicates the provisioner's testable methods without
# requiring the full Kitchen + Docker stack.
class ProvisionerTestHarness
  attr_accessor :config

  def initialize(config = {})
    @config = {
      chef_binary: "/opt/cinc/bin/cinc-client",
      chef_options: " -z",
      chef_log_level: "warn",
      chef_output_format: "doc",
      root_path: "/opt/kitchen",
      profile_ruby: false,
      slow_resource_report: false,
    }.merge(config)
  end

  def validate_config
    unless config[:chef_options].start_with? " "
      config[:chef_options].prepend(" ")
    end

    config[:chef_binary] = config[:chef_binary].strip
    config[:chef_log_level] = config[:chef_log_level].strip
    config[:chef_output_format] = config[:chef_output_format].strip

    config[:chef_log_level] = "warn" if config[:chef_log_level].empty?
    config[:chef_output_format] = "doc" if config[:chef_output_format].empty?
  end

  def run_command
    validate_config
    cmd = config[:chef_binary]
    cmd << config[:chef_options].to_s
    cmd << " -l #{config[:chef_log_level]}"
    cmd << " -F #{config[:chef_output_format]}"
    cmd << " -c #{File.join(config[:root_path], "client.rb")}"
    cmd << " -j #{File.join(config[:root_path], "dna.json")}"
    cmd << " --profile-ruby" if config[:profile_ruby]
    cmd << " --slow-report" if config[:slow_resource_report]

    chef_cmd(cmd)
  end

  # Minimal stub — in real code, ChefInfra wraps the command
  def chef_cmd(cmd)
    cmd
  end
end

RSpec.describe "Kitchen::Provisioner::Dokken" do
  let(:provisioner) { ProvisionerTestHarness.new(config) }
  let(:config) { {} }

  describe "#validate_config" do
    it "prepends space to chef_options when missing" do
      provisioner.config[:chef_options] = "-z"
      provisioner.validate_config
      expect(provisioner.config[:chef_options]).to eq(" -z")
    end

    it "does not double-prepend space to chef_options" do
      provisioner.config[:chef_options] = " -z"
      provisioner.validate_config
      expect(provisioner.config[:chef_options]).to eq(" -z")
    end

    it "strips whitespace from chef_binary" do
      provisioner.config[:chef_binary] = "  /opt/cinc/bin/cinc-client  "
      provisioner.validate_config
      expect(provisioner.config[:chef_binary]).to eq("/opt/cinc/bin/cinc-client")
    end

    it "strips whitespace from chef_log_level" do
      provisioner.config[:chef_log_level] = " debug "
      provisioner.validate_config
      expect(provisioner.config[:chef_log_level]).to eq("debug")
    end

    it "resets empty chef_log_level to default" do
      provisioner.config[:chef_log_level] = ""
      provisioner.validate_config
      expect(provisioner.config[:chef_log_level]).to eq("warn")
    end

    it "resets empty chef_output_format to default" do
      provisioner.config[:chef_output_format] = ""
      provisioner.validate_config
      expect(provisioner.config[:chef_output_format]).to eq("doc")
    end

    it "resets whitespace-only chef_log_level to default" do
      provisioner.config[:chef_log_level] = "   "
      provisioner.validate_config
      expect(provisioner.config[:chef_log_level]).to eq("warn")
    end
  end

  describe "#run_command" do
    it "constructs the default command correctly" do
      cmd = provisioner.run_command
      expect(cmd).to eq(
        "/opt/cinc/bin/cinc-client -z" \
        " -l warn" \
        " -F doc" \
        " -c /opt/kitchen/client.rb" \
        " -j /opt/kitchen/dna.json"
      )
    end

    it "includes --profile-ruby when enabled" do
      provisioner.config[:profile_ruby] = true
      cmd = provisioner.run_command
      expect(cmd).to include(" --profile-ruby")
      expect(cmd).not_to include("dna.json--profile-ruby")
    end

    it "includes --slow-report when enabled" do
      provisioner.config[:slow_resource_report] = true
      cmd = provisioner.run_command
      expect(cmd).to include(" --slow-report")
      expect(cmd).not_to include("dna.json--slow-report")
    end

    it "includes both flags when both enabled" do
      provisioner.config[:profile_ruby] = true
      provisioner.config[:slow_resource_report] = true
      cmd = provisioner.run_command
      expect(cmd).to include(" --profile-ruby")
      expect(cmd).to include(" --slow-report")
    end

    it "uses custom chef_binary" do
      provisioner.config[:chef_binary] = "/usr/local/bin/chef-client"
      cmd = provisioner.run_command
      expect(cmd).to start_with("/usr/local/bin/chef-client")
    end

    it "uses custom log level" do
      provisioner.config[:chef_log_level] = "debug"
      cmd = provisioner.run_command
      expect(cmd).to include("-l debug")
    end

    it "uses custom output format" do
      provisioner.config[:chef_output_format] = "min"
      cmd = provisioner.run_command
      expect(cmd).to include("-F min")
    end

    it "uses custom root path for config files" do
      provisioner.config[:root_path] = "/custom/path"
      cmd = provisioner.run_command
      expect(cmd).to include("-c /custom/path/client.rb")
      expect(cmd).to include("-j /custom/path/dna.json")
    end

    it "normalizes chef_options without leading space" do
      provisioner.config[:chef_options] = "-z --no-fork"
      cmd = provisioner.run_command
      expect(cmd).to include("cinc-client -z --no-fork")
    end
  end
end
