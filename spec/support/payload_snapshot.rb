require "json"

module Kitchen
  module Dokken
    module Spec
      # Whole-payload comparison against a checked-in fixture.
      #
      # `start_runner_container` builds a nested create request with roughly
      # twenty-five keys and six conditional branches. The driver spec asserts
      # individual keys, which is the right way to say what a setting is
      # *for* -- but it can only protect the keys somebody thought to assert.
      # A key that silently stops being sent, or moves from HostConfig to the
      # top level, breaks every user and no example.
      #
      # A snapshot inverts that: the whole payload is the assertion, so any
      # change shows up. The cost is that a snapshot diff is only as good as
      # the review it gets, which is why these live alongside explicit
      # assertions rather than replacing them -- the explicit ones say what
      # must be true, and the snapshot says what else moved.
      #
      # Regenerate with `UPDATE_SNAPSHOTS=1 bundle exec rake unit`, then read
      # the diff before committing it.
      module PayloadSnapshot
        # Where the fixtures live.
        FIXTURE_DIR = File.expand_path("../fixtures/payloads", __dir__)

        # Values that differ between machines or runs and would otherwise make
        # every snapshot fail on someone else's laptop.
        #
        # @param payload [Object] the structure to normalise
        # @param home [String] the scratch home directory to mask
        # @return [Object] the same structure with volatile values masked
        def self.scrub(payload, home:)
          case payload
          when Hash
            payload.each_with_object({}) { |(k, v), acc| acc[scrub(k, home: home)] = scrub(v, home: home) }
          when Array
            payload.map { |v| scrub(v, home: home) }
          when String
            payload.gsub(home, "<HOME>")
          else
            payload
          end
        end

        # Compare a payload against its fixture, or write the fixture.
        #
        # @param name [String] the fixture's basename
        # @param payload [Hash] the create request to compare
        # @param home [String] the scratch home directory to mask
        # @return [Array(String, String)] expected and actual JSON
        def self.compare(name, payload, home:)
          path = File.join(FIXTURE_DIR, "#{name}.json")
          actual = JSON.pretty_generate(scrub(payload, home: home))

          if ENV["UPDATE_SNAPSHOTS"] || !File.exist?(path)
            FileUtils.mkdir_p(FIXTURE_DIR)
            File.write(path, "#{actual}\n")
          end

          [File.read(path).strip, actual]
        end

        # A human-readable account of how two payloads differ.
        #
        # Minitest's diff on a 60-line JSON blob is unreadable, and the useful
        # question is almost always "which keys changed", not "which lines".
        #
        # @param expected [String] the fixture's JSON
        # @param actual [String] the generated JSON
        # @param name [String] the fixture name, for the regeneration hint
        # @return [String] the failure message
        def self.message(expected, actual, name)
          before = flatten(JSON.parse(expected))
          after  = flatten(JSON.parse(actual))

          removed = (before.keys - after.keys).sort
          added   = (after.keys - before.keys).sort
          changed = (before.keys & after.keys).reject { |k| before[k] == after[k] }.sort

          lines = ["the #{name} create payload no longer matches its snapshot:"]
          removed.each { |k| lines << "  - removed  #{k} (was #{before[k].inspect})" }
          added.each   { |k| lines << "  + added    #{k} = #{after[k].inspect}" }
          changed.each { |k| lines << "  ~ changed  #{k}: #{before[k].inspect} -> #{after[k].inspect}" }
          lines << ""
          lines << "  If this change is intended, regenerate with:"
          lines << "    UPDATE_SNAPSHOTS=1 bundle exec rake unit"
          lines.join("\n")
        end

        # Flatten nested structures to dotted paths, so a diff can name the
        # key that moved rather than the line that changed.
        #
        # @param value [Object] the structure to flatten
        # @param prefix [String] the path accumulated so far
        # @return [Hash{String => Object}] leaf values by path
        def self.flatten(value, prefix = "")
          case value
          when Hash
            # An empty hash has no leaves to recurse into, but dropping it
            # would leave `Tmpfs => {}` disappearing from the diff entirely --
            # so a failure could report no differences at all.
            return { prefix => {} } if value.empty?

            value.each_with_object({}) do |(k, v), acc|
              acc.merge!(flatten(v, prefix.empty? ? k.to_s : "#{prefix}.#{k}"))
            end
          when Array
            return { prefix => [] } if value.empty?

            value.each_with_object({}).with_index do |(v, acc), i|
              acc.merge!(flatten(v, "#{prefix}[#{i}]"))
            end
          else
            { prefix => value }
          end
        end
      end
    end
  end
end
