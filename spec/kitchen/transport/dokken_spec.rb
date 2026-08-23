require_relative "../../spec_helper"

require "kitchen/transport/dokken"

describe Kitchen::Transport::Dokken do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)         { stub(name: "default") }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      to_str: "default-almalinux-9"
    )
  end

  let(:config) { { docker_host_url: "unix:///var/run/docker.sock", docker_info: {} } }

  let(:transport) do
    Kitchen::Transport::Dokken.new(config).finalize_config!(instance)
  end

  describe "defaults" do
    it "waits an hour for reads, since a converge is not a quick request" do
      _(transport[:read_timeout]).must_equal 3600
    end

    it "waits an hour for writes" do
      _(transport[:write_timeout]).must_equal 3600
    end

    it "shells out to the docker cli for kitchen login" do
      _(transport[:login_command]).must_equal "docker"
    end

    it "declares transport api version 2" do
      _(Kitchen::Transport::Dokken.instance_variable_get(:@api_version)).must_equal 2
    end
  end

  describe ":host_ip_override default" do
    it "is host.docker.internal when kitchen itself runs in Docker Desktop" do
      Kitchen::Transport::Dokken.any_instance.stubs(:running_inside_docker_desktop?).returns(true)

      _(transport[:host_ip_override]).must_equal "host.docker.internal"
    end

    it "is localhost when the daemon is Docker Desktop on the host" do
      Kitchen::Transport::Dokken.any_instance.stubs(:running_inside_docker_desktop?).returns(false)
      Kitchen::Transport::Dokken.any_instance.stubs(:docker_for_mac_or_win?).returns(true)

      _(transport[:host_ip_override]).must_equal "localhost"
    end

    it "is false for a plain linux daemon" do
      Kitchen::Transport::Dokken.any_instance.stubs(:running_inside_docker_desktop?).returns(false)
      Kitchen::Transport::Dokken.any_instance.stubs(:docker_for_mac_or_win?).returns(false)

      _(transport[:host_ip_override]).must_equal false
    end
  end

  describe "#docker_for_mac_or_win?" do
    it "is true when the daemon calls itself docker-desktop" do
      ::Docker.stubs(:info).returns("Name" => "docker-desktop")

      _(transport.docker_for_mac_or_win?).must_equal true
    end

    it "is false for any other daemon name" do
      ::Docker.stubs(:info).returns("Name" => "some-linux-box")

      _(transport.docker_for_mac_or_win?).must_equal false
    end

    it "is false when the daemon cannot be reached at all" do
      ::Docker.stubs(:info).raises(Excon::Error::Socket.new(StandardError.new("no socket")))

      _(transport.docker_for_mac_or_win?).must_equal false
    end
  end

  describe "#connection" do
    let(:state) { { instance_name: "abc123-default-almalinux-9", data_container: {} } }

    before do
      config[:host_ip_override] = false
    end

    it "yields a Dokken connection" do
      transport.connection(state) do |conn|
        _(conn).must_be_kind_of Kitchen::Transport::Dokken::Connection
      end
    end

    it "reuses the connection when the options have not changed" do
      first = transport.connection(state)
      second = transport.connection(state)

      _(second).must_be_same_as first
    end

    it "builds a new connection when the state changes" do
      first = transport.connection(state)
      second = transport.connection(state.merge(instance_name: "other"))

      _(second).wont_be_same_as first
    end

    it "closes the previous connection before replacing it" do
      first = transport.connection(state)
      first.expects(:close)

      transport.connection(state.merge(instance_name: "other"))
    end

    it "carries the instance name and timeouts into the connection options" do
      opts = transport.send(:connection_options, config.to_hash.merge(state).merge(write_timeout: 42))

      _(opts[:instance_name]).must_equal "abc123-default-almalinux-9"
      _(opts[:timeout]).must_equal 42
      _(opts[:docker_host_url]).must_equal "unix:///var/run/docker.sock"
    end
  end

  describe Kitchen::Transport::Dokken::Connection do
    let(:options) do
      {
        logger: logger,
        instance_name: "abc123-default-almalinux-9",
        docker_host_url: "unix:///var/run/docker.sock",
        docker_host_options: {},
        timeout: 60,
        login_command: "docker",
        host_ip_override: false,
        data_container: data_container,
      }
    end

    let(:data_container) do
      {
        Name: "/abc123-default-almalinux-9-data",
        NetworkSettings: {
          IPAddress: "172.17.0.5",
          Ports: { "22/tcp": [{ HostIp: "0.0.0.0", HostPort: "32768" }] },
          Networks: { dokken: { IPAddress: "172.18.0.5" } },
        },
      }
    end

    let(:connection) { Kitchen::Transport::Dokken::Connection.new(options) }

    # The subclass is declared as `class Connection < Kitchen::Transport::Dokken::Connection`,
    # which resolves through the enclosing class's ancestors to Base::Connection.
    # Pin the resulting ancestry so a future edit to that line cannot silently
    # detach the connection from the Kitchen transport contract.
    it "is a Kitchen transport connection" do
      _(Kitchen::Transport::Dokken::Connection.superclass).must_equal Kitchen::Transport::Base::Connection
    end

    describe "#execute" do
      let(:runner) { mock("runner") }

      it "does nothing at all when handed a nil command" do
        ::Docker::Container.expects(:get).never

        _(connection.execute(nil)).must_be_nil
      end

      it "execs the command in the runner container" do
        ::Docker::Container.expects(:get)
          .with("abc123-default-almalinux-9", {}, anything)
          .returns(runner)
        runner.expects(:exec)
          .with(%w{echo hello}, wait: 60, "e" => { "TERM" => "xterm" })
          .returns([[], [], 0])

        connection.execute("echo hello")
      end

      it "word-splits the command the way a shell would" do
        ::Docker::Container.stubs(:get).returns(runner)
        runner.expects(:exec).with(["sh", "-c", "echo a b"], anything).returns([[], [], 0])

        connection.execute(%{sh -c "echo a b"})
      end

      it "streams container output to the kitchen logger" do
        ::Docker::Container.stubs(:get).returns(runner)
        runner.stubs(:exec).yields(:stdout, "hello from the container\n").returns([[], [], 0])

        connection.execute("echo hello")

        _(logged_output.string).must_include "hello from the container"
      end

      it "raises with the exit code and the command when the exec fails" do
        ::Docker::Container.stubs(:get).returns(runner)
        runner.stubs(:exec).returns([[], [], 42])

        err = _ { connection.execute("false") }.must_raise Kitchen::Transport::DockerExecFailed

        _(err.exit_code).must_equal 42
        _(err.message).must_include "false"
      end

      it "is a TransportFailed, so kitchen reports it as an action failure" do
        _(Kitchen::Transport::DockerExecFailed.ancestors).must_include Kitchen::Transport::TransportFailed
      end

      it "retries a transient docker error and then succeeds" do
        ::Docker::Container.stubs(:get)
          .raises(::Docker::Error::TimeoutError)
          .then.returns(runner)
        runner.stubs(:exec).returns([[], [], 0])

        connection.execute("true")
      end

      it "gives up and re-raises once the retries are exhausted" do
        ::Docker::Container.stubs(:get).raises(::Docker::Error::IOError)

        _ { connection.execute("true") }.must_raise ::Docker::Error::IOError
      end

      it "does not retry an error that retrying cannot fix" do
        ::Docker::Container.expects(:get).once.raises(::Docker::Error::NotFoundError)

        _ { connection.execute("true") }.must_raise ::Docker::Error::NotFoundError
      end
    end

    describe "#work_image" do
      it "is the instance name when no prefix is configured" do
        _(connection.send(:work_image)).must_equal "abc123-default-almalinux-9"
      end

      it "is prefixed when image_prefix is set" do
        options[:image_prefix] = "myorg"

        _(connection.send(:work_image)).must_equal "myorg/abc123-default-almalinux-9"
      end
    end

    describe "#rsync_available?" do
      it "is true when rsync is executable at the expected path" do
        File.stubs(:executable?).with(Kitchen::Transport::Dokken::Connection::RSYNC_PATH).returns(true)

        _(connection.send(:rsync_available?)).must_equal true
      end

      it "is false when it is not" do
        File.stubs(:executable?).with(Kitchen::Transport::Dokken::Connection::RSYNC_PATH).returns(false)

        _(connection.send(:rsync_available?)).must_equal false
      end
    end

    describe "#login_command" do
      before do
        connection.stubs(:`).returns("80\n")
      end

      it "runs docker exec against the runner container" do
        cmd = connection.login_command

        _(cmd.command).must_equal "docker"
        _(cmd.arguments).must_include "abc123-default-almalinux-9"
        _(cmd.arguments.first).must_equal "exec"
      end

      it "asks for an interactive login shell" do
        _(connection.login_command.arguments.last(3)).must_equal ["/bin/bash", "-login", "-i"]
      end

      # `tput cols` ends in a newline. Passing it through unstripped exports
      # COLUMNS with an embedded newline, which bash then reads as the start
      # of another command line.
      it "strips the newline off the terminal dimensions" do
        args = connection.login_command.arguments

        _(args).must_include "COLUMNS=80"
        _(args).must_include "LINES=80"
        _(args.none? { |a| a.include?("\n") }).must_equal true
      end
    end

    describe "#upload address selection" do
      # Deliberately no `before` hook building the connection: Base::Connection
      # dups its options at construction, so an example that adjusts `options`
      # has to be the first thing to touch `connection`.
      def uploaded_endpoint
        captured = nil
        connection.stubs(:upload_files).with { |_l, _r, ip, port, _dir| captured = [ip, port]; true }
        connection.upload(["/tmp/sandbox"], "/opt/kitchen")
        captured
      end

      it "uses the override host with the published port when host_ip_override is set" do
        options[:host_ip_override] = "host.docker.internal"

        _(uploaded_endpoint).must_equal ["host.docker.internal", "32768"]
      end

      it "uses the container's own address over a unix socket bound to all interfaces" do
        _(uploaded_endpoint).must_equal ["172.17.0.5", "22"]
      end

      # NetworkSettings.IPAddress is only populated for the default bridge. The
      # data container is given a NetworkingConfig endpoint on the dokken
      # network, so the legacy field is empty and the address lives under
      # Networks.<name>. Reading the empty one built `root@:/opt/kitchen` and
      # rsync died with "Could not resolve hostname".
      it "uses the network-scoped address when the container is on a user-defined network" do
        data_container[:NetworkSettings][:IPAddress] = ""

        _(uploaded_endpoint).must_equal ["172.18.0.5", "22"]
      end

      it "finds the address whatever the network is called" do
        data_container[:NetworkSettings][:IPAddress] = ""
        data_container[:NetworkSettings][:Networks] = { custom_net: { IPAddress: "10.9.0.7" } }

        _(uploaded_endpoint).must_equal ["10.9.0.7", "22"]
      end

      it "prefers the top-level address when the daemon does populate it" do
        _(uploaded_endpoint).must_equal ["172.17.0.5", "22"]
      end

      it "ignores a network entry that carries no address" do
        data_container[:NetworkSettings][:IPAddress] = ""
        data_container[:NetworkSettings][:Networks] = {
          none: { IPAddress: "" },
          dokken: { IPAddress: "172.18.0.5" },
        }

        _(uploaded_endpoint).must_equal ["172.18.0.5", "22"]
      end

      # Better than uploading to an empty hostname and letting ssh report it.
      it "says so plainly when the container has no address at all" do
        data_container[:NetworkSettings][:IPAddress] = ""
        data_container[:NetworkSettings][:Networks] = {}

        err = _ { connection.upload(["/tmp/sandbox"], "/opt/kitchen") }
          .must_raise Kitchen::Transport::TransportFailed

        _(err.message).must_include "no address on any docker network"
      end

      it "uses the published host mapping over a unix socket bound to one interface" do
        data_container[:NetworkSettings][:Ports][:"22/tcp"][0][:HostIp] = "127.0.0.1"

        _(uploaded_endpoint).must_equal ["127.0.0.1", "32768"]
      end

      describe "over tcp" do
        before do
          options[:docker_host_url] = "tcp://10.0.0.1:2376"
          ::Docker::Container.stubs(:all).returns(
            [stub(info: {
              "Names" => ["/abc123-default-almalinux-9-data"],
              "NetworkSettings" => { "Networks" => { "dokken" => { "IPAddress" => "172.18.0.5" } } },
            })]
          )
        end

        it "prefers the container's dokken-network address on the published port" do
          connection.stubs(:port_open?).with("172.18.0.5", "32768").returns(true)

          _(uploaded_endpoint).must_equal ["172.18.0.5", "32768"]
        end

        it "falls back to port 22 on the container address" do
          connection.stubs(:port_open?).with("172.18.0.5", "32768").returns(false)
          connection.stubs(:port_open?).with("172.18.0.5", "22").returns(true)

          _(uploaded_endpoint).must_equal ["172.18.0.5", "22"]
        end

        it "falls back to the docker host itself when the container is unreachable" do
          connection.stubs(:port_open?).returns(false)

          _(uploaded_endpoint).must_equal ["10.0.0.1", "32768"]
        end

        # The data container only joins the dokken network when network_mode
        # is left at its default: start_data_container attaches a
        # NetworkingConfig endpoint "unless %w{host bridge}.include?", and
        # names it after network_mode. So with `network_mode: bridge`, `host`,
        # or any custom network there is no Networks["dokken"] entry at all,
        # and looking the address up there found nil and died with
        # `undefined method '[]' for nil`.
        #
        # The unix path never had this problem -- it reads the address out of
        # kitchen state with #data_container_ip, which walks whatever networks
        # are actually attached. These examples hold the tcp path to the same
        # behaviour.
        # The daemon really does report the container this way when
        # network_mode names a network other than dokken -- stubbing
        # Container.all with a dokken entry, as the happy-path example above
        # does, describes a container the driver would never have created
        # under this configuration.
        def daemon_reports(networks)
          ::Docker::Container.stubs(:all).returns(
            [stub(info: {
              "Names" => ["/abc123-default-almalinux-9-data"],
              "NetworkSettings" => { "Networks" => networks },
            })]
          )
        end

        it "finds the address on a user-defined network that is not called dokken" do
          data_container[:NetworkSettings][:IPAddress] = ""
          data_container[:NetworkSettings][:Networks] = { mynet: { IPAddress: "172.20.0.7" } }
          daemon_reports("bridge" => { "IPAddress" => "172.17.0.9" },
                         "mynet"  => { "IPAddress" => "172.20.0.7" })
          connection.stubs(:port_open?).with("172.20.0.7", "32768").returns(true)

          _(uploaded_endpoint).must_equal ["172.20.0.7", "32768"]
        end

        it "finds the address when only the default bridge is attached" do
          data_container[:NetworkSettings][:Networks] = { bridge: { IPAddress: "172.17.0.9" } }
          daemon_reports("bridge" => { "IPAddress" => "172.17.0.9" })
          connection.stubs(:port_open?).with("172.17.0.9", "32768").returns(true)

          _(uploaded_endpoint).must_equal ["172.17.0.9", "32768"]
        end

        # A host-networked data container has no address of its own. The
        # docker host is the right endpoint in that case, and it is already
        # the method's own fallback -- but the lookup crashed before ever
        # reaching it.
        it "falls back to the docker host when the container has no address anywhere" do
          data_container[:NetworkSettings][:IPAddress] = ""
          data_container[:NetworkSettings][:Networks] = {}

          _(uploaded_endpoint).must_equal ["10.0.0.1", "32768"]
        end

        # The address is already in kitchen state, put there by the driver
        # after it started the container. Asking the daemon for it again is a
        # round trip that can also come back empty: Docker::Container.all
        # lists only running containers, so a data container that had exited
        # produced `undefined method 'info' for nil` rather than anything a
        # user could act on.
        it "does not need to ask the daemon which containers exist" do
          ::Docker::Container.stubs(:all).returns([])
          connection.stubs(:port_open?).with("172.18.0.5", "32768").returns(true)

          _(uploaded_endpoint).must_equal ["172.18.0.5", "32768"]
        end
      end

      it "raises a helpful error for a docker_host_url it cannot route" do
        options[:docker_host_url] = "npipe:////./pipe/docker_engine"

        err = _ { connection.upload(["/tmp/sandbox"], "/opt/kitchen") }.must_raise Kitchen::UserError

        _(err.message).must_include "tcp://"
      end
    end

    describe "#upload file transfer" do
      before do
        # Resolve the scratch directory before stubbing Dir.tmpdir -- mocha
        # installs the stub before evaluating the argument to #returns, and
        # Dir.mktmpdir reads Dir.tmpdir.
        scratch = stub_home!
        Dir.stubs(:tmpdir).returns(scratch)
      end

      it "writes the insecure private key with owner-only permissions" do
        connection.stubs(:upload_via_rsync)
        connection.stubs(:rsync_available?).returns(true)

        connection.upload(["/tmp/sandbox"], "/opt/kitchen")

        key = File.join(tmphome, "dokken", Process.uid.to_s, "id_rsa")
        _(File.stat(key).mode & 0o777).must_equal 0o600
        _(File.read(key)).must_equal connection.insecure_ssh_private_key
      end

      it "builds an rsync command that will not prompt or cache host keys" do
        cmd = connection.send(:rsync_command, ["/a", "/b"], "/opt/kitchen", "172.17.0.5", "22", "/keys")

        _(cmd).must_include "-o StrictHostKeyChecking=no"
        _(cmd).must_include "-o UserKnownHostsFile=/dev/null"
        _(cmd).must_include "-i /keys/id_rsa"
        _(cmd).must_include "-p 22"
        _(cmd).must_include "/a /b root@172.17.0.5:/opt/kitchen"
      end

      # The old code shelled out with backticks and rescued Errno::ENOENT to
      # detect a missing rsync. Backticks run through /bin/sh, which reports
      # "not found" as exit status 127 and never raises -- so the SCP fallback
      # was unreachable on every platform that lacks /usr/bin/rsync.
      it "falls back to scp when rsync is not installed" do
        connection.stubs(:rsync_available?).returns(false)
        connection.expects(:upload_via_rsync).never
        Net::SCP.expects(:upload!).with do |host, user, local, remote, opts|
          [host, user, local, remote] == ["172.17.0.5", "root", "/tmp/sandbox", "/opt/kitchen"] &&
            opts[:recursive] == true && opts[:ssh][:port] == "22"
        end

        connection.upload(["/tmp/sandbox"], "/opt/kitchen")
      end

      it "uses rsync when it is installed" do
        connection.stubs(:rsync_available?).returns(true)
        connection.expects(:upload_via_rsync)
        Net::SCP.expects(:upload!).never

        connection.upload(["/tmp/sandbox"], "/opt/kitchen")
      end

      # A failed rsync used to be discarded entirely, so the converge carried
      # on against a container with no cookbooks in it and failed later with a
      # confusing error.
      it "raises when rsync exits non-zero" do
        connection.stubs(:rsync_available?).returns(true)
        Open3.stubs(:capture2e).returns(["rsync: connection unexpectedly closed", stub(success?: false, exitstatus: 12)])

        err = _ { connection.upload(["/tmp/sandbox"], "/opt/kitchen") }.must_raise Kitchen::Transport::TransportFailed

        _(err.message).must_include "rsync"
        _(err.message).must_include "connection unexpectedly closed"
      end

      it "is quiet when rsync succeeds" do
        connection.stubs(:rsync_available?).returns(true)
        Open3.stubs(:capture2e).returns(["", stub(success?: true, exitstatus: 0)])

        connection.upload(["/tmp/sandbox"], "/opt/kitchen")
      end
    end
  end
end
