module Kitchen
  module Dokken
    module Spec
      # A tiny generative-testing helper.
      #
      # Example-based tests check the inputs someone thought of. The
      # `parse_port` crash on `[::1]:8500:8500` survived a suite with eleven
      # hand-written port examples precisely because nobody thought of a
      # fourth colon -- there was no example for it, so there was no failure.
      #
      # This generates input instead, including the malformed kind, and
      # asserts properties that must hold for *every* input rather than
      # outputs for particular ones.
      #
      # Deliberately not a dependency. The generators below are a few dozen
      # lines, they need no shrinking to be useful at this scale, and a fixed
      # default seed keeps failures reproducible: set `PORT_SEED` to explore
      # further, and the failure message tells you which seed to reuse.
      module Generative
        # The seed used unless PORT_SEED says otherwise.
        DEFAULT_SEED = 20_240_101

        # @return [Integer] the seed in effect for this run
        def self.seed
          @seed ||= Integer(ENV.fetch("PORT_SEED", DEFAULT_SEED))
        end

        # @return [Random] a generator seeded for reproducibility
        def self.random
          Random.new(seed)
        end

        # Port specs that are valid docker syntax and must parse cleanly.
        #
        # @param count [Integer] how many to generate
        # @return [Array<String>]
        def self.valid_port_specs(count)
          rng = random

          Array.new(count) do
            container = rng.rand(1..65_535)
            # Docker pairs ranges off one for one, so a container range can
            # only be published against a host range of the same size. This
            # generator used to emit `55876:45105-45108`, which docker
            # rejects outright with "invalid ranges specified for container
            # and host Ports" -- so the property tests were asserting over
            # input no daemon would accept.
            span = rng.rand < 0.25 ? rng.rand(0..4) : 0
            span = [span, 65_535 - container].min
            spec = span.zero? ? container.to_s : "#{container}-#{container + span}"

            if rng.rand < 0.5
              host = rng.rand(1..65_535 - span)
              host_spec = span.zero? ? host.to_s : "#{host}-#{host + span}"
              spec = "#{host_spec}:#{spec}"
            end
            spec = "#{rng.rand(1..254)}.0.0.#{rng.rand(1..254)}:#{spec}" if spec.include?(":") && rng.rand < 0.5
            spec = "#{spec}/#{%w{tcp udp}.sample(random: rng)}" if rng.rand < 0.4
            spec
          end
        end

        # Input that is not valid docker port syntax.
        #
        # Every one of these must be rejected with a Kitchen::UserError that
        # names the offending spec -- never a NoMethodError, TypeError or
        # ArgumentError from somewhere deep in the parser, which is what the
        # user actually got before.
        #
        # @return [Array<String>]
        def self.malformed_port_specs
          [
            "",                    # nothing at all
            ":",                   # separators only
            "::",
            "1:2:3:4",             # one field too many
            "[::1]:8500:8500",     # an IPv6 host address, which splits into five
            "::1:8500",            # a bare IPv6 address
            "0.0.0.0:1:2:3",       # a host ip plus one field too many
            "a:b:c:d:e",           # five fields
          ].freeze
        end

        # Port specs whose ranges are inverted, which docker rejects.
        #
        # @return [Array<String>]
        def self.inverted_range_specs
          ["9001-9000", "2:9001-9000", "0.0.0.0:2:80-70"].freeze
        end

        # Typos that `String#split` turns into nil rather than into an empty
        # field, because it drops trailing empty results.
        #
        # Every one of these was found by fuzzing, and every one used to
        # crash with an error naming a type rather than a port:
        # "8080-" gave `comparison of Integer with nil failed`, "-" gave
        # `undefined method '>' for nil`, "/" gave
        # `undefined method 'include?' for nil`.
        #
        # @return [Array<String>]
        def self.lossy_split_specs
          [
            "8080-",      # ["8080"] -- no high port
            "-8080",      # ["", "8080"] -- no low port
            "-",          # [] -- no ports at all
            "--",
            "/",          # [] -- no port, no protocol
            "/tcp",       # ["", "tcp"] -- protocol but no port
            "80-/tcp",
            "8080:/tcp",
            "0.0.0.0:80:/udp",
            "abc-def",    # a range of things that are not numbers
          ].freeze
        end

        # Random strings from the alphabet a port spec is built from.
        #
        # Fuzzing found three crash classes that none of the hand-written
        # examples did, so it earns a place in the suite rather than being a
        # one-off investigation. The count is small enough to stay fast; set
        # PORT_SEED to sweep a different slice.
        #
        # @param count [Integer] how many to generate
        # @return [Array<String>]
        def self.fuzzed_port_specs(count)
          alphabet = (%w{: / - .} + ("0".."9").to_a + %w{a b [ ] tcp udp}).freeze
          rng = random

          Array.new(count) do
            Array.new(rng.rand(0..9)) { alphabet.sample(random: rng) }.join
          end
        end
      end
    end
  end
end
