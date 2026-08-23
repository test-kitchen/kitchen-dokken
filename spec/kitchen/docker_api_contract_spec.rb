require_relative "../spec_helper"

require "docker"
require "kitchen/driver/dokken"
require "kitchen/transport/dokken"
require "kitchen/helpers"

# Every other spec in this suite talks to a double. That is what makes them
# fast and hermetic, and it is also what makes them blind: a docker-api
# release that renames a method, drops an argument or changes a return shape
# breaks every kitchen-dokken user while all 400 specs stay green, because
# the doubles happily answer to whatever the old code asked for.
#
# This file is the seam. It asserts, against the real docker-api classes,
# that every entry point kitchen-dokken calls still exists and still accepts
# the number of arguments we pass. Nothing here talks to a daemon -- it is
# pure reflection over the loaded gem -- so it stays as fast as the rest of
# the suite while being the one file that notices a renovate bump breaking
# us before a user does.
describe "the docker-api contract" do
  # The widest and narrowest number of positional arguments a method accepts.
  #
  # @param method [Method, UnboundMethod]
  # @return [Range] acceptable positional argument counts
  def arity_range(method)
    required = 0
    optional = 0
    unlimited = false

    method.parameters.each do |type, _name|
      case type
      when :req then required += 1
      when :opt then optional += 1
      when :rest then unlimited = true
      end
    end

    unlimited ? (required..Float::INFINITY) : (required..(required + optional))
  end

  # Assert a class method exists and tolerates a call of `argc` arguments.
  def assert_class_seam(owner, name, argc)
    assert owner.respond_to?(name),
      "kitchen-dokken calls #{owner}.#{name}, which docker-api no longer defines"

    range = arity_range(owner.method(name))
    assert range.cover?(argc),
      "kitchen-dokken calls #{owner}.#{name} with #{argc} argument(s), " \
      "but docker-api accepts #{range} (#{owner.method(name).parameters.inspect})"
  end

  # Assert an instance method exists and tolerates a call of `argc` arguments.
  def assert_instance_seam(owner, name, argc)
    assert owner.method_defined?(name),
      "kitchen-dokken calls ##{name} on a #{owner}, which docker-api no longer defines"

    range = arity_range(owner.instance_method(name))
    assert range.cover?(argc),
      "kitchen-dokken calls #{owner}##{name} with #{argc} argument(s), " \
      "but docker-api accepts #{range} (#{owner.instance_method(name).parameters.inspect})"
  end

  # Each entry is a call kitchen-dokken actually makes, with the file and line
  # it makes it from, so a failure points at the code to change rather than
  # at this table.
  CLASS_SEAMS = [
    [::Docker,            :info,            0, "helpers.rb - docker_info"],
    [::Docker,            :info,            1, "transport - docker_for_mac_or_win?"],
    [::Docker,            :authenticate!,   1, "driver - docker_config_creds"],
    [::Docker::Connection, :new,            2, "driver/transport - docker_connection"],
    [::Docker::Container, :get,             3, "driver - container_exist?, wait_running_state"],
    [::Docker::Container, :create,          2, "driver - create_container_for_platform"],
    [::Docker::Container, :all,             2, "driver - chef container lookup"],
    [::Docker::Container, :all,             0, "transport - candidate ip lookup"],
    [::Docker::Image,     :exist?,          1, "helpers.rb - create_data_image"],
    [::Docker::Image,     :exist?,          3, "driver - build_work_image"],
    [::Docker::Image,     :get,             3, "driver - remove_image"],
    [::Docker::Image,     :build,           3, "driver - build_work_image"],
    [::Docker::Image,     :build_from_dir,  2, "helpers.rb - create_data_image"],
    [::Docker::Image,     :create,          3, "driver - pull_image"],
    [::Docker::Network,   :get,             3, "driver - make_dokken_network"],
    [::Docker::Network,   :create,          2, "driver - make_dokken_network"],
  ].freeze

  INSTANCE_SEAMS = [
    [::Docker::Container, :start!,          0, "driver - start_container!"],
    [::Docker::Container, :stop,            1, "driver - stop_container(force: false)"],
    [::Docker::Container, :delete,          1, "driver - delete_container(force: true, v: true)"],
    [::Docker::Container, :info,            0, "driver - container_state"],
    [::Docker::Container, :json,            0, "driver - state[:runner_container]"],
    [::Docker::Container, :exec,            2, "transport - Connection#execute"],
    [::Docker::Image,     :remove,          1, "driver - remove_image(force: true)"],
    [::Docker::Image,     :tag,             1, "helpers.rb - create_data_image"],
    [::Docker::Image,     :id,              0, "driver - work image id"],
  ].freeze

  CLASS_SEAMS.each do |owner, name, argc, where|
    it "#{owner}.#{name} still accepts #{argc} argument(s) (#{where})" do
      assert_class_seam(owner, name, argc)
    end
  end

  INSTANCE_SEAMS.each do |owner, name, argc, where|
    it "#{owner}##{name} still accepts #{argc} argument(s) (#{where})" do
      assert_instance_seam(owner, name, argc)
    end
  end

  # The error classes kitchen-dokken rescues by name. A rescue for a constant
  # that no longer exists is not a syntax error -- it is a NameError raised
  # only on the failure path, i.e. only in front of a user who was already
  # having a bad day.
  RESCUED_ERRORS = %i{
    NotFoundError
    ConflictError
    UnexpectedResponseError
    TimeoutError
    ServerError
  }.freeze

  RESCUED_ERRORS.each do |name|
    it "Docker::Error::#{name} still exists to be rescued" do
      assert ::Docker::Error.const_defined?(name),
        "kitchen-dokken rescues Docker::Error::#{name}, which docker-api no longer defines"
      assert ::Docker::Error.const_get(name) <= Exception,
        "Docker::Error::#{name} is no longer an exception class"
    end
  end

  it "Excon::Error::Socket still exists, since docker_info rescues it" do
    assert defined?(::Excon::Error::Socket),
      "helpers.rb rescues Excon::Error::Socket to report an unreachable daemon"
  end

  # The fakes in spec/support stand in for these classes everywhere else.
  # If a fake grows a method the real class does not have, every spec using
  # it is asserting against fiction.
  describe "the spec doubles" do
    # Methods that exist purely to let a spec see what happened. They have no
    # counterpart on the real class and are not part of the contract.
    SPY_METHODS = %i{
      start_count stop_args delete_args remove_args tag_args
    }.freeze

    def assert_double_matches(double_class, real_class)
      surface = double_class.public_instance_methods(false) - SPY_METHODS

      refute_empty surface, "#{double_class} stands in for nothing"

      surface.each do |name|
        assert real_class.method_defined?(name),
          "#{double_class} implements ##{name}, but #{real_class} does not have it: " \
          "specs using this double are asserting against a method that no longer exists"

        double_range = arity_range(double_class.instance_method(name))
        real_range   = arity_range(real_class.instance_method(name))

        assert double_range.first <= real_range.first,
          "#{double_class}##{name} requires more arguments (#{double_range}) than " \
          "#{real_class}##{name} does (#{real_range}), so the double rejects calls the real class accepts"
      end
    end

    it "FakeContainer only implements methods Docker::Container really has" do
      assert_double_matches(Kitchen::Dokken::Spec::FakeContainer, ::Docker::Container)
    end

    it "FakeImage only implements methods Docker::Image really has" do
      assert_double_matches(Kitchen::Dokken::Spec::FakeImage, ::Docker::Image)
    end
  end
end
