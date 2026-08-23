require_relative "../spec_helper"

require "kitchen/helpers"

# Properties of the port parser, as opposed to examples of it.
#
# `spec/kitchen/helpers_spec.rb` has eleven hand-written `parse_port`
# examples and they all passed while `[::1]:8500:8500` crashed with
# `undefined method 'split' for nil`, because no example had four colons in
# it. Examples can only cover the inputs someone imagined.
#
# Each example here asserts something that must hold for every input, and
# checks it against generated ones -- including deliberately malformed input,
# which is where the parser was actually broken.
describe "port parsing properties" do
  Generative = Kitchen::Dokken::Spec::Generative

  let(:instance) { Kitchen::Dokken::Spec::FakeInstance.new(provisioner: { root_path: "/opt/kitchen" }) }
  let(:host)     { Kitchen::Dokken::Spec::HelperHost.new(config: {}, instance: instance) }

  # Everything the parser is allowed to raise. Anything else means an input
  # reached code that was not expecting it, which is a bug even when the
  # input is nonsense.
  ALLOWED_ERRORS = [Kitchen::UserError].freeze

  # Run a block and return any exception it raised that we did not sanction.
  def unexpected_error_from(spec)
    yield
    nil
  rescue *ALLOWED_ERRORS
    nil
  rescue StandardError => e
    "#{spec.inspect} raised #{e.class}: #{e.message}"
  end

  describe "malformed input" do
    # This is the property the original bug violated. It is worth stating
    # even though the specific inputs are now listed by name: the point is
    # that the parser must fail *as a parser*, with an error naming the bad
    # input, rather than falling through into nil arithmetic.
    it "rejects every malformed spec with a Kitchen error, never a nil crash" do
      failures = Generative.malformed_port_specs.filter_map do |spec|
        unexpected_error_from(spec) { host.parse_port(spec) }
      end

      _(failures).must_equal [], "the parser leaked an unexpected exception:\n  #{failures.join("\n  ")}"
    end

    it "names the offending spec so the user can find it in their kitchen.yml" do
      Generative.malformed_port_specs.each do |spec|
        err = _ { host.parse_port(spec) }.must_raise Kitchen::UserError

        _(err.message).must_include spec.inspect,
          "the error for #{spec.inspect} does not say which port spec was wrong"
      end
    end

    it "rejects an inverted range rather than silently producing no ports" do
      Generative.inverted_range_specs.each do |spec|
        _ { host.parse_port(spec) }.must_raise Kitchen::UserError
      end
    end

    # `String#split` drops trailing empty fields, so "8080-" is ["8080"] and
    # "/" is []. Each of these left a nil that only failed several lines
    # later, with a message naming a type instead of the port the user
    # mistyped. Fuzzing found them; they are listed by name so a regression
    # names the input rather than a seed.
    it "rejects the typos that split turns into nil" do
      failures = Generative.lossy_split_specs.filter_map do |spec|
        unexpected_error_from(spec) { host.parse_port(spec) }
      end

      _(failures).must_equal [], "the parser leaked an unexpected exception:\n  #{failures.join("\n  ")}"
    end

    it "explains a malformed range instead of comparing against nil" do
      err = _ { host.parse_port("8080-") }.must_raise Kitchen::UserError

      _(err.message).must_include "8080-"
      _(err.message).must_include "8080-8082", "the error should show the shape it wanted"
    end

    it "explains a spec with no container port at all" do
      err = _ { host.parse_port("/tcp") }.must_raise Kitchen::UserError

      _(err.message).must_include "no container port"
    end

    # The properties above are stated over hand-picked inputs. This states
    # the same one over input nobody chose, which is how the three crashes
    # above were found in the first place.
    it "never leaks an unexpected exception, over fuzzed input" do
      specs = Generative.fuzzed_port_specs(2_000)

      failures = specs.filter_map { |spec| unexpected_error_from(spec) { host.parse_port(spec) } }

      _(failures.uniq.first(10)).must_equal [],
        "seed #{Generative.seed}; re-run with PORT_SEED=#{Generative.seed} to reproduce\n" \
        "  #{failures.uniq.first(10).join("\n  ")}"
    end

    # The coercions are what the driver actually calls, and they map over
    # parse_port. A malformed entry anywhere in the list has to surface as
    # the same clean error, not as a half-built ExposedPorts hash.
    it "propagates the error through both coercions" do
      Generative.malformed_port_specs.each do |spec|
        _ { host.coerce_exposed_ports(["80", spec]) }.must_raise Kitchen::UserError
        _ { host.coerce_port_bindings(["80", spec]) }.must_raise Kitchen::UserError
      end
    end
  end

  describe "well-formed input" do
    let(:specs) { Generative.valid_port_specs(250) }

    def seed_note
      "seed #{Generative.seed}; re-run with PORT_SEED=#{Generative.seed} to reproduce"
    end

    it "parses every generated spec without raising" do
      failures = specs.filter_map { |spec| unexpected_error_from(spec) { host.parse_port(spec) } }

      _(failures).must_equal [], "#{seed_note}\n  #{failures.join("\n  ")}"
    end

    # Docker requires the protocol on a port binding key. #427 was a bug
    # where an implicit tcp port came out as "80" rather than "80/tcp" and
    # the daemon silently ignored the binding.
    it "always qualifies the container port with a protocol" do
      offenders = specs.flat_map { |spec| host.parse_port(spec) }
        .map { |p| p["container_port"] }
        .reject { |p| p.match?(%r{\A\d+/(tcp|udp)\z}) }

      _(offenders.uniq).must_equal [], seed_note
    end

    it "never leaves a binding key without the three fields the driver reads" do
      incomplete = specs.flat_map { |spec| host.parse_port(spec) }
        .reject { |p| (%w{host_ip host_port container_port} - p.keys).empty? }

      _(incomplete).must_equal [], seed_note
    end

    # ExposedPorts and PortBindings go into the same create call and are
    # derived from the same setting. If they ever disagreed about which
    # container ports exist, docker would publish a port that was never
    # exposed, or expose one nothing is bound to.
    it "keeps ExposedPorts and PortBindings agreeing on the set of ports" do
      exposed  = host.coerce_exposed_ports(specs).keys.sort
      bindings = host.coerce_port_bindings(specs).keys.sort

      _(exposed).must_equal bindings, seed_note
    end

    # A range is inclusive at both ends: 8080-8082 is three ports, not two.
    it "expands an inclusive range to one entry per port" do
      rng = Random.new(Generative.seed)

      20.times do
        low  = rng.rand(1..60_000)
        span = rng.rand(0..5)
        parsed = host.parse_port("#{low}-#{low + span}")

        _(parsed.length).must_equal(span + 1, "#{low}-#{low + span} should expand to #{span + 1} ports")
      end
    end

    # Docker pairs the two ranges off one for one. Only the container side
    # used to be expanded, so all three bindings were handed the whole host
    # range as their HostPort -- which the daemon reads as "any free port in
    # this range", making the mapping correct only while every port in it
    # happened to be free.
    it "pairs each container port with its own host port" do
      parsed = host.parse_port("0.0.0.0:9000-9002:9000-9002")

      _(parsed.map { |p| p["host_ip"] }.uniq).must_equal ["0.0.0.0"]
      _(parsed.map { |p| p["host_port"] }).must_equal %w{9000 9001 9002}
      _(parsed.map { |p| p["container_port"] }).must_equal %w{9000/tcp 9001/tcp 9002/tcp}
    end

    it "pairs ranges positionally when the two sides do not share a base" do
      parsed = host.parse_port("19300-19302:29300-29302")

      _(parsed.map { |p| [p["host_port"], p["container_port"]] }).must_equal(
        [%w{19300 29300/tcp}, %w{19301 29301/tcp}, %w{19302 29302/tcp}]
      )
    end
  end
end
