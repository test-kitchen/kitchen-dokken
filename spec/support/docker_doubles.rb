# Lightweight stand-ins for the parts of the docker-api gem that
# kitchen-dokken touches. These are deliberately dumb value objects: they
# record what they were handed and hand back what the spec asked for, so a
# failing expectation points at kitchen-dokken rather than at a fake.

module Kitchen
  module Dokken
    module Spec
      # A stand-in for `::Docker::Container`.
      #
      # Only the handful of messages kitchen-dokken sends are implemented.
      class FakeContainer
        # @return [Hash] the container's inspect payload
        attr_reader :info

        # @return [Integer] how many times {#start} was called
        attr_reader :start_count

        # @return [Array<Hash>] the option hashes passed to {#stop}
        attr_reader :stop_args

        # @return [Array<Hash>] the option hashes passed to {#delete}
        attr_reader :delete_args

        # @param name [String] the container name, as Docker reports it
        # @param info [Hash] the inspect payload to report from {#info}
        def initialize(name: "dokken", info: nil)
          @info = info || {
            "Name" => "/#{name}",
            "Names" => ["/#{name}"],
            "State" => { "Running" => true, "FinishedAt" => "0001-01-01T00:00:00Z" },
          }
          @start_count = 0
          @stop_args = []
          @delete_args = []
        end

        # Record a start request.
        #
        # The driver calls the bang form, because docker-api's `#start`
        # rescues ServerError and so hides every reason the daemon refused.
        #
        # @return [self]
        def start!
          @start_count += 1
          self
        end
        alias start start!

        # Record a stop request.
        #
        # @param opts [Hash] options forwarded by the driver
        # @return [self]
        def stop(**opts)
          @stop_args << opts
          self
        end

        # Record a delete request.
        #
        # @param opts [Hash] options forwarded by the driver
        # @return [self]
        def delete(**opts)
          @delete_args << opts
          self
        end

        # The inspect payload, which the driver stores in kitchen state.
        #
        # @return [Hash]
        def json
          @info
        end
      end

      # A stand-in for `::Docker::Image`.
      class FakeImage
        # @return [String] the image id
        attr_reader :id

        # @return [Array<Hash>] the option hashes passed to {#remove}
        attr_reader :remove_args

        # @return [Array<Hash>] the option hashes passed to {#tag}
        attr_reader :tag_args

        # @param id [String] the image id to report
        def initialize(id: "sha256:cafebabe")
          @id = id
          @remove_args = []
          @tag_args = []
        end

        # Record a remove request.
        #
        # @param opts [Hash] options forwarded by the driver
        # @return [self]
        def remove(**opts)
          @remove_args << opts
          self
        end

        # Record a tag request.
        #
        # @param opts [Hash] options forwarded by the driver
        # @return [self]
        def tag(opts = {})
          @tag_args << opts
          self
        end
      end

      # Build the `docker info` payload the driver and transport expect.
      #
      # @param operating_system [String, nil] the daemon's `OperatingSystem`
      # @param extra [Hash] any additional keys to merge in
      # @return [Hash] a `docker info` payload
      def self.docker_info(operating_system: "Ubuntu 24.04", **extra)
        { "OperatingSystem" => operating_system, "Name" => "somehost" }.merge(extra.transform_keys(&:to_s))
      end
    end
  end
end
