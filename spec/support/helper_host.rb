require "kitchen/helpers"

module Kitchen
  module Dokken
    module Spec
      # A minimal object that mixes in {::Dokken::Helpers}.
      #
      # The helpers module is written against the contract a Test Kitchen
      # plugin offers (`config`, `instance`, `self[]`, `info`, `debug`), but it
      # is a plain module, so a spec does not need a whole Kitchen instance to
      # exercise it. This host supplies exactly that contract and nothing else.
      class HelperHost
        include ::Dokken::Helpers

        # @return [Hash] the plugin configuration the helpers read
        attr_reader :config

        # @return [Object] the Kitchen instance double the helpers read
        attr_reader :instance

        # @return [Array<String>] every message passed to {#info} or {#debug}
        attr_reader :logged

        # @param config [Hash] plugin configuration
        # @param instance [Object] a Kitchen instance double
        def initialize(config: {}, instance: nil)
          @config = config
          @instance = instance
          @logged = []
        end

        # Read a configuration key, mirroring `Kitchen::Configurable#[]`.
        #
        # @param key [Symbol] the configuration key
        # @return [Object, nil] the configured value
        def [](key)
          @config[key]
        end

        # Record an informational message.
        #
        # @param msg [String] the message
        # @return [void]
        def info(msg)
          @logged << msg
        end

        # Record a debug message.
        #
        # @param msg [String] the message
        # @return [void]
        def debug(msg)
          @logged << msg
        end
      end

      # A stand-in for the Kitchen instance the helpers reach through.
      class FakeInstance
        # @return [String] the instance name, e.g. `default-almalinux-9`
        attr_reader :name

        # @return [Hash] the provisioner configuration
        attr_reader :provisioner

        # @return [Object] the platform double
        attr_reader :platform

        # @param name [String] the instance name
        # @param provisioner [Hash] provisioner configuration
        # @param platform [Object] a platform double
        def initialize(name: "default-almalinux-9", provisioner: {}, platform: nil)
          @name = name
          @provisioner = provisioner
          @platform = platform
        end
      end
    end
  end
end
