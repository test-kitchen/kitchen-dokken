require "docker"

module Kitchen
  module Dokken
    module Spec
      # An in-memory Docker daemon.
      #
      # The rest of this suite stubs `::Docker::Container.get` and friends per
      # example, which makes each call answer in isolation: `get` can be told
      # to return a container that `create` was never asked for, `start` can
      # succeed on something that does not exist, and a container can be
      # stopped and still report itself running. Specs written that way can
      # only assert that a method was called -- never that the sequence of
      # calls adds up to a working `kitchen create`.
      #
      # FakeDaemon keeps state instead, and enforces the invariants the real
      # daemon enforces:
      #
      # - `get` on an unknown name raises `Docker::Error::NotFoundError`
      # - `create` with a name already in use raises `Docker::Error::ConflictError`
      # - a container is created stopped, and only `start` makes it running
      # - `stop` sets `FinishedAt`, which is what `wait_running_state` watches
      # - `delete` removes it, so a later `get` raises again
      #
      # That is enough for a spec to run a whole `create`/`destroy` cycle and
      # assert on what the daemon ends up holding, rather than on which
      # methods were called in what order.
      class FakeDaemon
        # The `FinishedAt` docker reports for a container that has never run.
        NEVER_FINISHED = "0001-01-01T00:00:00Z".freeze

        # @return [Hash{String => Container}] containers by name
        attr_reader :containers

        # @return [Array<String>] image references known to the daemon
        attr_reader :images

        # @return [Hash{String => Hash}] networks by name, with their options
        attr_reader :networks

        # @return [Array<Array>] every mutating call, in order, for sequence
        #   assertions: [:create_container, "name"], [:start, "name"], ...
        attr_reader :calls

        # What each image EXPOSEs, for containers created with
        # `PublishAllPorts`. The kitchen-cache image serves the sandbox over
        # ssh, which is the only EXPOSE kitchen-dokken depends on.
        EXPOSED_PORTS = {
          "dokken/kitchen-cache:latest" => ["22/tcp"].freeze,
        }.freeze

        # @param images [Array<String>] image references that already exist
        # @param exposed_ports [Hash{String => Array<String>}] image EXPOSEs
        def initialize(images: [], exposed_ports: {})
          @containers     = {}
          @images         = images.dup
          @networks       = {}
          @calls          = []
          @next_id        = 0
          @exposed_ports  = EXPOSED_PORTS.merge(exposed_ports)
        end

        # The ports an image declares with EXPOSE.
        #
        # @param image [String] an image reference
        # @return [Array<String>] port specs, e.g. ["22/tcp"]
        def exposed_ports_for(image)
          @exposed_ports.fetch(image) do
            # Match on the repo when the caller used a short name, since the
            # driver strips the registry before creating a container.
            _, ports = @exposed_ports.find { |ref, _| ref.split(":").first.end_with?(image.to_s.split(":").first) }
            ports || []
          end
        end

        # A stateful stand-in for `::Docker::Container`.
        #
        # Only the messages kitchen-dokken sends are implemented, and each one
        # changes the daemon's state the way the real API would.
        class Container
          # @return [String] the container name, without docker's leading slash
          attr_reader :name

          # @return [Hash] the create options the driver supplied
          attr_reader :create_options

          # @return [Integer] how many times {#start} was called
          attr_reader :start_count

          # @param daemon [FakeDaemon] the daemon holding this container
          # @param name [String] the container name
          # @param options [Hash] the create options
          # @param id [String] the container id
          def initialize(daemon, name, options, id)
            @daemon         = daemon
            @name           = name
            @create_options = options
            @id             = id
            @running        = false
            @finished_at    = NEVER_FINISHED
            @start_count    = 0
            @deleted        = false
          end

          # @return [Boolean] whether the container is running
          def running?
            @running
          end

          # @return [Boolean] whether the container has been deleted
          def deleted?
            @deleted
          end

          # The inspect payload, shaped the way the driver reads it.
          #
          # String keys throughout, because that is what the docker API
          # returns and what `state[:data_container] = container.json` stores.
          # The transport reads the same payload with Symbol keys, after
          # Kitchen::StateFile has symbolized it -- see
          # spec/kitchen/plugin_handoff_spec.rb.
          #
          # @return [Hash]
          def info
            {
              "Id"    => @id,
              "Name"  => "/#{@name}",
              "Names" => ["/#{@name}"],
              "Image" => @create_options["Image"],
              "State" => {
                "Running"    => @running,
                "FinishedAt" => @finished_at,
              },
              "Config"         => @create_options,
              "HostConfig"     => host_config,
              "NetworkSettings" => network_settings,
            }
          end
          alias json info

          # Start the container.
          #
          # @return [self]
          # @raise [Docker::Error::NotFoundError] if it has been deleted
          def start
            raise ::Docker::Error::NotFoundError, "No such container: #{@name}" if @deleted

            @start_count += 1
            @running = true
            @daemon.record(:start, @name)
            self
          end

          # Stop the container, stamping FinishedAt the way docker does.
          #
          # @param _opts [Hash] options the driver passes; not modelled
          # @return [self]
          def stop(_opts = {})
            raise ::Docker::Error::NotFoundError, "No such container: #{@name}" if @deleted

            @running = false
            @finished_at = "2024-01-01T00:00:00Z"
            @daemon.record(:stop, @name)
            self
          end

          # Remove the container from the daemon.
          #
          # @param _opts [Hash] options the driver passes; not modelled
          # @return [self]
          def delete(_opts = {})
            @deleted = true
            @daemon.forget_container(@name)
            @daemon.record(:delete, @name)
            self
          end

          # @param _command [Array<String>] the command to run
          # @param _options [Hash] exec options
          # @return [Array(Array, Array, Integer)] stdout, stderr, exit code
          def exec(_command, _options = {})
            [[], [], 0]
          end

          private

          # @return [Hash] the container's HostConfig, never nil
          def host_config
            @create_options["HostConfig"] || {}
          end

          # What the daemon fills in once a container exists.
          #
          # Modelled rather than hard-coded because the transport's whole
          # ssh-endpoint ladder reads it, and two of its rules are easy to get
          # wrong from memory:
          #
          # - published ports appear under `Ports` keyed by `<port>/<proto>`,
          #   and a container that published nothing still has the key
          # - `IPAddress` at the top level is populated *only* for the default
          #   bridge. On a user-defined network it is empty and the address
          #   lives under `Networks.<name>.IPAddress`. Getting this wrong is
          #   what produced `root@:/opt/kitchen` in the field.
          #
          # @return [Hash]
          def network_settings
            mode = host_config["NetworkMode"].to_s
            endpoints = @create_options.dig("NetworkingConfig", "EndpointsConfig") || {}

            networks = endpoints.keys.each_with_object({}) do |network, acc|
              acc[network] = { "IPAddress" => "172.20.0.#{@id[-2..].to_i(16) % 250 + 2}" }
            end
            networks["bridge"] = { "IPAddress" => "172.17.0.2" } if mode == "bridge"

            {
              # Only the default bridge populates the legacy top-level field.
              "IPAddress" => mode == "bridge" ? "172.17.0.2" : "",
              "Networks"  => networks,
              "Ports"     => published_ports,
            }
          end

          # @return [Hash] the daemon's view of what is published
          def published_ports
            bindings = host_config["PortBindings"] || {}

            ports = bindings.each_with_object({}) do |(port, specs), acc|
              acc[port] = Array(specs).map do |spec|
                {
                  "HostIp"   => spec["HostIp"].to_s.empty? ? "0.0.0.0" : spec["HostIp"],
                  # An empty HostPort means "publish on a random port", which
                  # the daemon resolves at start time.
                  "HostPort" => spec["HostPort"].to_s.empty? ? "32768" : spec["HostPort"],
                }
              end
            end

            # PublishAllPorts publishes whatever the image EXPOSEs on random
            # host ports. The data container relies on this: it sets no
            # PortBindings at all unless data_ssh_port is configured, and the
            # transport still expects to find 22/tcp published.
            if host_config["PublishAllPorts"]
              @daemon.exposed_ports_for(@create_options["Image"]).each_with_index do |port, i|
                ports[port] ||= [{ "HostIp" => "0.0.0.0", "HostPort" => (32768 + i).to_s }]
              end
            end

            ports
          end

          # Start the container.
          #
          # @return [self]
        end

        # A stateful stand-in for `::Docker::Image`.
        class Image
          # @return [String] the image reference
          attr_reader :id

          # @param daemon [FakeDaemon] the daemon holding this image
          # @param id [String] the image reference
          def initialize(daemon, id)
            @daemon = daemon
            @id = id
          end

          # @param _opts [Hash] options the driver passes; not modelled
          # @return [self]
          def remove(_opts = {})
            @daemon.forget_image(@id)
            @daemon.record(:remove_image, @id)
            self
          end

          # @param opts [Hash] repo/tag/force, as docker expects
          # @return [self]
          def tag(opts = {})
            @daemon.add_image("#{opts["repo"]}:#{opts["tag"]}")
            self
          end
        end

        # Record a mutating call for later sequence assertions.
        #
        # @param action [Symbol] what happened
        # @param subject [String] what it happened to
        # @return [void]
        def record(action, subject)
          @calls << [action, subject]
        end

        # @param name [String] the container name
        # @return [Container]
        # @raise [Docker::Error::NotFoundError] when nothing is registered
        def container_get(name)
          @containers.fetch(name) do
            raise ::Docker::Error::NotFoundError, "No such container: #{name}"
          end
        end

        # @param options [Hash] the docker create payload
        # @return [Container] the newly created, not-yet-running container
        # @raise [Docker::Error::ConflictError] when the name is taken
        def container_create(options)
          name = options["name"]
          if @containers.key?(name)
            raise ::Docker::Error::ConflictError, "Conflict. The container name #{name.inspect} is already in use"
          end

          @next_id += 1
          record(:create_container, name)
          @containers[name] = Container.new(self, name, options, format("sha256:%064x", @next_id))
        end

        # @return [Array<Container>] every container the daemon holds
        def container_all
          @containers.values
        end

        # @param name [String] the container name to drop
        # @return [void]
        def forget_container(name)
          @containers.delete(name)
        end

        # @param ref [String] an image reference
        # @return [Boolean]
        def image_exist?(ref)
          @images.include?(ref)
        end

        # @param ref [String] an image reference
        # @return [Image]
        # @raise [Docker::Error::NotFoundError] when the image is unknown
        def image_get(ref)
          raise ::Docker::Error::NotFoundError, "No such image: #{ref}" unless image_exist?(ref)

          Image.new(self, ref)
        end

        # @param ref [String] an image reference to register
        # @return [Image]
        def add_image(ref)
          @images << ref unless @images.include?(ref)
          Image.new(self, ref)
        end

        # @param ref [String] an image reference to drop
        # @return [void]
        def forget_image(ref)
          @images.delete(ref)
        end

        # @param name [String] the network name
        # @return [Hash] the network's options
        # @raise [Docker::Error::NotFoundError] when the network is unknown
        def network_get(name)
          @networks.fetch(name) do
            raise ::Docker::Error::NotFoundError, "No such network: #{name}"
          end
        end

        # @param name [String] the network name
        # @param options [Hash] network creation options
        # @return [Hash] the stored options
        def network_create(name, options = {})
          record(:create_network, name)
          @networks[name] = options
        end

        # Point the real docker-api entry points at this daemon.
        #
        # Deliberately not mocha. `stubs(:get) { ... }` silently *ignores* the
        # block and returns nil, so a daemon installed that way answers
        # nothing at all while the specs using it still pass. Replacing the
        # singleton methods outright is the only way to get a stub with real
        # behaviour, and `assert_seam!` below makes the replacement fail loudly
        # if docker-api ever stops defining what we are replacing -- the
        # protection mocha's `:prevent` gives everywhere else in this suite.
        #
        # @return [self]
        def install!
          raise "FakeDaemon already installed" if @originals

          @originals = {}

          seams.each do |owner, name, implementation|
            assert_seam!(owner, name)
            @originals[[owner, name]] = owner.method(name)
            owner.define_singleton_method(name, &implementation)
          end

          self
        end

        # Put the real docker-api methods back.
        #
        # @return [self]
        def uninstall!
          return self unless @originals

          @originals.each { |(owner, name), original| owner.define_singleton_method(name, original) }
          @originals = nil
          self
        end

        private

        # The docker-api entry points this daemon answers, and how.
        #
        # @return [Array<Array(Module, Symbol, Proc)>]
        def seams
          daemon = self

          [
            [::Docker::Container, :get,     ->(name, _opts = {}, _conn = nil) { daemon.container_get(name) }],
            [::Docker::Container, :create,  ->(opts, _conn = nil) { daemon.container_create(opts) }],
            [::Docker::Container, :all,     ->(_opts = {}, _conn = nil) { daemon.container_all }],
            [::Docker::Image,     :exist?,  ->(ref, _opts = {}, _conn = nil) { daemon.image_exist?(ref) }],
            [::Docker::Image,     :get,     ->(ref, _opts = {}, _conn = nil) { daemon.image_get(ref) }],
            [::Docker::Network,   :get,     ->(name, _opts = {}, _conn = nil) { daemon.network_get(name) }],
            [::Docker::Network,   :create,  ->(name, opts = {}, _conn = nil) { daemon.network_create(name, opts) }],
          ]
        end

        # Refuse to replace a method docker-api does not define.
        #
        # @param owner [Module] the docker-api class
        # @param name [Symbol] the method being replaced
        # @return [void]
        def assert_seam!(owner, name)
          return if owner.respond_to?(name)

          raise NameError,
            "FakeDaemon replaces #{owner}.#{name}, which docker-api no longer defines. " \
            "kitchen-dokken calls it, so this is a real break, not a test-only one."
        end
      end
    end
  end
end
