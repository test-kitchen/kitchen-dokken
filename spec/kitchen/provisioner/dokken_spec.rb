require_relative "../../spec_helper"

require "kitchen/provisioner/dokken"

describe Kitchen::Provisioner::Dokken do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(os_type: nil, name: "almalinux-9") }
  let(:suite)         { stub(name: "default") }
  let(:driver_config) { { chef_version: "latest" } }
  let(:driver)        { driver_config }
  let(:transport)     { stub }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      driver: driver,
      transport: transport,
      to_str: "default-almalinux-9"
    )
  end

  let(:config) do
    {
      kitchen_root: "/rooty",
      test_base_path: "/basist",
      docker_info: Kitchen::Dokken::Spec.docker_info,
    }
  end

  let(:provisioner) do
    Kitchen::Provisioner::Dokken.new(config).finalize_config!(instance)
  end

  describe "defaults" do
    it "stages the sandbox at /opt/kitchen inside the container" do
      _(provisioner[:root_path]).must_equal "/opt/kitchen"
    end

    it "runs chef in local mode" do
      _(provisioner[:chef_options]).must_equal " -z"
    end

    it "logs at warn and formats with doc" do
      _(provisioner[:chef_log_level]).must_equal "warn"
      _(provisioner[:chef_output_format]).must_equal "doc"
    end

    it "does not profile ruby" do
      _(provisioner[:profile_ruby]).must_equal false
    end

    it "cleans the dokken sandbox after a converge" do
      _(provisioner[:clean_dokken_sandbox]).must_equal true
    end

    it "declares provisioner api version 2" do
      _(Kitchen::Provisioner::Dokken.instance_variable_get(:@api_version)).must_equal 2
    end
  end

  describe "product_name" do
    it "defaults to chef" do
      _(provisioner[:product_name]).must_equal "chef"
    end

    it "can be set to cinc" do
      config[:product_name] = "cinc"
      _(provisioner[:product_name]).must_equal "cinc"
    end
  end

  # Dokken never downloads chef: it mounts /opt/chef out of a volume container
  # built from the driver's chef_version. Copying that version onto the
  # provisioner is what keeps license acceptance asking about the right one.
  describe "product_version" do
    it "is copied from the driver's chef_version" do
      driver_config[:chef_version] = "18.4.12"
      _(provisioner[:product_version]).must_equal "18.4.12"
    end
  end

  describe "chef_binary default" do
    it "is the chef-client path when product_name is chef" do
      _(provisioner[:chef_binary]).must_equal "/opt/chef/bin/chef-client"
    end

    it "is the cinc-client path when product_name is cinc" do
      config[:product_name] = "cinc"
      _(provisioner[:chef_binary]).must_equal "/opt/cinc/bin/cinc-client"
    end

    it "respects an explicit override" do
      config[:product_name] = "cinc"
      config[:chef_binary]  = "/usr/local/bin/cinc-client"
      _(provisioner[:chef_binary]).must_equal "/usr/local/bin/cinc-client"
    end
  end

  describe "#validate_config" do
    it "inserts the separating space the user forgot before their options" do
      config[:chef_options] = "-z --no-color"
      provisioner.validate_config

      _(provisioner[:chef_options]).must_equal " -z --no-color"
    end

    it "leaves options that already start with a space alone" do
      config[:chef_options] = " -z"
      provisioner.validate_config

      _(provisioner[:chef_options]).must_equal " -z"
    end

    it "is idempotent, so a second call does not add another space" do
      config[:chef_options] = "-z"
      provisioner.validate_config
      provisioner.validate_config

      _(provisioner[:chef_options]).must_equal " -z"
    end

    it "strips stray whitespace off the binary and the log settings" do
      config[:chef_binary] = "  /opt/chef/bin/chef-client "
      config[:chef_log_level] = " info "
      config[:chef_output_format] = " minimal "
      provisioner.validate_config

      _(provisioner[:chef_binary]).must_equal "/opt/chef/bin/chef-client"
      _(provisioner[:chef_log_level]).must_equal "info"
      _(provisioner[:chef_output_format]).must_equal "minimal"
    end

    it "falls back to the defaults when the user passes empty strings" do
      config[:chef_log_level] = "   "
      config[:chef_output_format] = ""
      provisioner.validate_config

      _(provisioner[:chef_log_level]).must_equal "warn"
      _(provisioner[:chef_output_format]).must_equal "doc"
    end
  end

  describe "#run_command" do
    def command
      provisioner.send(:run_command)
    end

    it "invokes the configured chef binary" do
      _(command).must_include "/opt/chef/bin/chef-client -z"
    end

    it "runs in local mode with the configured log level and format" do
      _(command).must_include " -z"
      _(command).must_include " -l warn"
      _(command).must_include " -F doc"
    end

    it "points chef at the client.rb and dna.json in the sandbox" do
      _(command).must_include " -c /opt/kitchen/client.rb"
      _(command).must_include " -j /opt/kitchen/dna.json"
    end

    it "honours a custom root_path" do
      config[:root_path] = "/opt/somewhere"

      _(command).must_include " -c /opt/somewhere/client.rb"
    end

    it "uses the cinc binary when product_name is cinc" do
      config[:product_name] = "cinc"

      _(command).must_include "/opt/cinc/bin/cinc-client -z"
      _(command).wont_include "chef-client"
    end

    # `cmd << flag` with no separator ran the flag together with the preceding
    # argument, producing `-j /opt/kitchen/dna.json--profile-ruby`, so chef
    # looked for a json file by that name and gave up.
    it "does not run --profile-ruby into the dna.json path" do
      config[:profile_ruby] = true

      _(command).wont_include "dna.json--profile-ruby"
      _(command).must_include " --profile-ruby"
    end

    # ChefInfra#chef_args already appends the flag; adding it here too put it
    # on the command line twice.
    it "asks for --profile-ruby exactly once" do
      config[:profile_ruby] = true

      _(command.scan("--profile-ruby").length).must_equal 1
    end

    it "does not run --slow-report into the dna.json path" do
      config[:slow_resource_report] = true

      _(command).wont_include "dna.json--slow-report"
      _(command).must_include " --slow-report"
    end

    it "asks for --slow-report exactly once" do
      config[:slow_resource_report] = true

      _(command.scan("--slow-report").length).must_equal 1
    end

    # Only the parent builds this flag, and only the parent knows that an
    # Integer means a threshold rather than a bare switch.
    it "passes a numeric slow_resource_report threshold through" do
      config[:slow_resource_report] = 15

      _(command).must_include "--slow-report 15"
    end

    it "omits both optional flags by default" do
      _(command).wont_include "--profile-ruby"
      _(command).wont_include "--slow-report"
    end

    # run_command used to build the command line by appending to the very
    # string held in config[:chef_binary], so asking for it twice returned the
    # arguments twice over.
    it "is idempotent" do
      _(command).must_equal command
    end

    it "does not rewrite the configured chef_binary" do
      command

      _(provisioner[:chef_binary]).must_equal "/opt/chef/bin/chef-client"
    end
  end

  describe "#write_run_command" do
    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
      provisioner.dokken_create_sandbox
    end

    it "writes the command into the kitchen sandbox" do
      provisioner.send(:write_run_command, "chef-client -z")

      _(File.read("#{provisioner.dokken_kitchen_sandbox}/run_command")).must_equal "chef-client -z"
    end

    # The file is read by /bin/sh inside a Linux container, so it must not
    # pick up the host's line endings.
    it "writes in binary mode so no line-ending translation happens" do
      provisioner.send(:write_run_command, "a\nb")

      _(File.binread("#{provisioner.dokken_kitchen_sandbox}/run_command")).must_equal "a\nb"
    end
  end

  describe "#cleanup_dokken_sandbox" do
    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
      provisioner.create_sandbox
    end

    it "empties the sandbox but keeps the directory" do
      File.write(File.join(provisioner.sandbox_path, "dna.json"), "{}")
      FileUtils.mkdir_p(File.join(provisioner.sandbox_path, "cookbooks"))

      provisioner.send(:cleanup_dokken_sandbox)

      _(Dir.glob("#{provisioner.sandbox_path}/*")).must_equal []
      _(File.directory?(provisioner.sandbox_path)).must_equal true
    end

    it "is a no-op on an already empty sandbox" do
      provisioner.send(:cleanup_dokken_sandbox)

      _(File.directory?(provisioner.sandbox_path)).must_equal true
    end
  end

  describe "#call" do
    let(:state)      { { instance_name: "abc123-default-almalinux-9" } }
    let(:connection) { mock("connection") }

    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
      provisioner.stubs(:create_sandbox)
      provisioner.stubs(:write_run_command)
      provisioner.stubs(:cleanup_dokken_sandbox)
      provisioner.stubs(:remote_docker_host?).returns(false)
      provisioner.stubs(:running_inside_docker?).returns(false)
      transport.stubs(:connection).yields(connection).returns(nil)
      connection.stubs(:execute)
      connection.stubs(:execute_with_retry)
      connection.stubs(:upload)
    end

    it "runs the staged command script rather than a long command line" do
      connection.expects(:execute_with_retry).with { |cmd, *_rest| cmd == "sh /opt/kitchen/run_command" }

      provisioner.call(state)
    end

    it "passes the retry settings through" do
      config[:retry_on_exit_code] = [35]
      config[:max_retries] = 3
      config[:wait_for_retry] = 5
      connection.expects(:execute_with_retry).with { |_cmd, codes, max, wait| [codes, max, wait] == [[35], 3, 5] }

      provisioner.call(state)
    end

    # A local daemon bind-mounts the sandbox straight into the container, so
    # copying it over ssh would be pure overhead.
    it "does not upload the sandbox for a local docker host" do
      connection.expects(:upload).never

      provisioner.call(state)
    end

    it "uploads the sandbox for a remote docker host" do
      provisioner.stubs(:remote_docker_host?).returns(true)
      provisioner.stubs(:sandbox_dirs).returns(["/tmp/sandbox/dna.json"])
      connection.expects(:upload).with(["/tmp/sandbox/dna.json"], "/opt/kitchen")

      provisioner.call(state)
    end

    it "uploads the sandbox when kitchen itself runs in a container" do
      provisioner.stubs(:running_inside_docker?).returns(true)
      provisioner.stubs(:sandbox_dirs).returns([])
      connection.expects(:upload)

      provisioner.call(state)
    end

    it "translates a transport failure into a kitchen action failure" do
      connection.stubs(:execute_with_retry).raises(Kitchen::Transport::TransportFailed, "exec failed")

      err = _ { provisioner.call(state) }.must_raise Kitchen::ActionFailed

      _(err.message).must_include "exec failed"
    end

    it "still cleans the sandbox when the converge fails" do
      connection.stubs(:execute_with_retry).raises(Kitchen::Transport::TransportFailed, "boom")
      provisioner.expects(:cleanup_dokken_sandbox)

      _ { provisioner.call(state) }.must_raise Kitchen::ActionFailed
    end

    it "leaves the sandbox in place when clean_dokken_sandbox is off" do
      config[:clean_dokken_sandbox] = false
      provisioner.expects(:cleanup_dokken_sandbox).never

      provisioner.call(state)
    end
  end

  describe "#check_license" do
    let(:acceptor) { mock }

    before do
      LicenseAcceptance::Acceptor.stubs(:new).returns(acceptor)
    end

    it "returns without prompting when product is cinc" do
      config[:product_name] = "cinc"
      acceptor.expects(:license_required?).with("cinc", "latest").returns(false)
      acceptor.expects(:check_and_persist).never

      provisioner.check_license
    end

    it "performs the license check when product is chef and a license is required" do
      acceptor.expects(:license_required?).with("chef", "latest").returns(true)
      acceptor.expects(:id_from_mixlib).with("chef").returns("chef")
      acceptor.expects(:check_and_persist).with("chef", "latest")
      acceptor.stubs(:acceptance_value).returns("accept-no-persist")

      provisioner.check_license
      _(provisioner[:chef_license]).must_equal "accept-no-persist"
    end

    it "checks the driver's chef version, not a bare latest" do
      driver_config[:chef_version] = "18.4.12"
      acceptor.expects(:license_required?).with("chef", "18.4.12").returns(false)

      provisioner.check_license
    end

    it "keeps a license the user already accepted in kitchen.yml" do
      config[:chef_license] = "accept"
      acceptor.expects(:license_required?).returns(true)
      acceptor.expects(:id_from_mixlib).returns("chef")
      acceptor.expects(:check_and_persist)
      acceptor.stubs(:acceptance_value).returns("accept-no-persist")

      provisioner.check_license

      _(provisioner[:chef_license]).must_equal "accept"
    end

    it "explains how to accept the license when the user declines" do
      acceptor.expects(:license_required?).returns(true)
      acceptor.expects(:id_from_mixlib).returns("chef")
      product = stub(id: "chef", pretty_name: "Chef Infra Client")
      acceptor.expects(:check_and_persist).raises(
        LicenseAcceptance::LicenseNotAcceptedError.new(product, [product])
      )

      _ { provisioner.check_license }.must_raise LicenseAcceptance::LicenseNotAcceptedError

      _(logged_output.string).must_include "CHEF_LICENSE"
    end

    it "skips the check when product is chef but no license is required" do
      acceptor.expects(:license_required?).with("chef", "latest").returns(false)
      acceptor.expects(:check_and_persist).never

      provisioner.check_license
    end

    # Helper: patch the parent's check_license to a sentinel so we can
    # verify our override delegated via super, then restore it.
    def with_stubbed_super
      parent = Kitchen::Provisioner::ChefInfra
      original = parent.instance_method(:check_license)
      parent.define_method(:check_license) { :super_called }
      begin
        yield
      ensure
        parent.define_method(:check_license, original)
      end
    end

    it "delegates to super when the parent doesn't define license_acceptance_id (kitchen-cinc parent)" do
      # Simulate the kitchen-cinc rebinding where ChefInfra is an alias for
      # CincInfra and license_acceptance_id is not defined.
      provisioner.stubs(:respond_to?).with(any_parameters).returns(true)
      provisioner.stubs(:respond_to?).with(:license_acceptance_id, true).returns(false)

      with_stubbed_super do
        _(provisioner.check_license).must_equal :super_called
      end
    end

    it "delegates to super when LicenseAcceptance is not loaded (partial cinc shim)" do
      # Simulate a partial kitchen-cinc drop-in shim: license_acceptance_id
      # exists but the LicenseAcceptance constant isn't autoloaded -- our body
      # would crash on Acceptor.new, so the guard must delegate instead.
      stash = LicenseAcceptance
      Object.send(:remove_const, :LicenseAcceptance)
      begin
        with_stubbed_super do
          _(provisioner.check_license).must_equal :super_called
        end
      ensure
        Object.const_set(:LicenseAcceptance, stash)
      end
    end
  end

  describe "#runner_container_name" do
    it "is the kitchen instance name" do
      _(provisioner.send(:runner_container_name)).must_equal "default-almalinux-9"
    end
  end
end
