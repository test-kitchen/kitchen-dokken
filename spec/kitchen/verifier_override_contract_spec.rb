require_relative "../spec_helper"

require "kitchen/helpers"
require "kitchen/verifier/base"
require "kitchen/provisioner/base"
require "kitchen/transport/dokken"

# kitchen-dokken replaces three methods on Kitchen::Verifier::Base and two on
# Kitchen::Provisioner::Base. Overriding a base class in another gem is a
# standing bet that the gem's internals will not move, and nothing in this
# suite used to notice when they did -- Kitchen::Verifier::Base#call has since
# grown a `downloads` block and an `ensure cleanup_sandbox` that the
# replacement in helpers.rb does not have.
#
# This is the same idea as spec/kitchen/docker_api_contract_spec.rb, aimed at
# test-kitchen instead of docker-api: pin the upstream facts the override
# depends on, so a release that invalidates one fails here rather than in
# front of a user.
describe "the test-kitchen methods kitchen-dokken overrides" do
  HELPERS_FILE = File.expand_path("../../lib/kitchen/helpers.rb", __dir__)

  # Every method kitchen-dokken replaces, and the class it replaces it on.
  OVERRIDDEN = [
    [Kitchen::Verifier::Base,    :call],
    [Kitchen::Verifier::Base,    :create_sandbox],
    [Kitchen::Verifier::Base,    :sandbox_path],
    [Kitchen::Provisioner::Base, :create_sandbox],
    [Kitchen::Provisioner::Base, :sandbox_path],
  ].freeze

  # If test-kitchen ever moves one of these behind a prepended module, or
  # renames it, the replacement stops taking effect -- silently. For `call`
  # that would mean the stock verifier running against a dokken instance and
  # uploading a sandbox that is already bind-mounted.
  OVERRIDDEN.each do |owner, method|
    it "#{owner}##{method} is still the one kitchen-dokken defines" do
      source = owner.instance_method(method).source_location&.first

      _(source).must_equal HELPERS_FILE,
        "#{owner}##{method} now resolves to #{source.inspect}; kitchen-dokken's " \
        "replacement in helpers.rb is no longer the one that runs"
    end
  end

  # The vocabulary the replacement `call` uses. A rename upstream turns into a
  # NoMethodError on the verify path, i.e. only in front of a user.
  VERIFIER_VOCABULARY = %i{
    install_command
    init_command
    prepare_command
    run_command
    sandbox_dirs
    cleanup_sandbox
  }.freeze

  VERIFIER_VOCABULARY.each do |method|
    it "Kitchen::Verifier::Base still defines ##{method}" do
      _(Kitchen::Verifier::Base.method_defined?(method) ||
        Kitchen::Verifier::Base.private_method_defined?(method)).must_equal true
    end
  end

  # This is the fact that makes *not* calling cleanup_sandbox correct rather
  # than an oversight, so it is worth asserting rather than asserting about.
  #
  # Dokken's verifier sandbox is a stable per-instance directory the driver
  # bind-mounts into a long-lived container. A bind mount is bound to an inode,
  # not to a path: removing the directory severs it permanently, and the
  # mkdir_p in the next create_sandbox does not put it back. Upstream can
  # rmtree safely only because a stock sandbox is a throwaway mktmpdir.
  describe "Kitchen::Verifier::Base#cleanup_sandbox" do
    it "removes the sandbox directory itself, not just its contents" do
      dir = Dir.mktmpdir("dokken-cleanup-contract")
      File.write(File.join(dir, "suite.rb"), "")

      verifier = Kitchen::Verifier::Base.new
      verifier.stubs(:sandbox_path).returns(dir)
      verifier.stubs(:debug)
      verifier.send(:cleanup_sandbox)

      _(File.exist?(dir)).must_equal false,
        "cleanup_sandbox no longer removes the directory; the reason " \
        "kitchen-dokken skips it may no longer hold -- re-read the comment " \
        "on Kitchen::Verifier::Base#call in lib/kitchen/helpers.rb"
    ensure
      FileUtils.remove_entry(dir) if dir && File.directory?(dir)
    end
  end

  # The shape kitchen-dokken's own provisioner uses instead, and the one a
  # future bind-mount-safe verifier cleanup would have to use: empty the
  # directory, keep the inode the mount is attached to.
  it "emptying a directory by glob leaves the directory in place" do
    dir = Dir.mktmpdir("dokken-cleanup-contract")
    File.write(File.join(dir, "suite.rb"), "")

    FileUtils.rmtree(Dir.glob("#{dir}/*"))

    _(File.directory?(dir)).must_equal true
    _(Dir.glob("#{dir}/*")).must_be_empty
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  # Keeps the one real gap visible. If a future test-kitchen drops :downloads
  # the gap closes itself and this can go; while it is there, so is the
  # unimplemented feature.
  describe "the downloads support kitchen-dokken does not implement" do
    it "is still a setting test-kitchen offers" do
      _(Kitchen::Provisioner::Base.defaults.key?(:downloads)).must_equal true
    end

    # Wiring downloads up needs this too, so the two have to land together:
    # the base class raises, and Transport::Dokken::Connection does not
    # override it.
    it "needs a transport download, which the base class only declares" do
      _(Kitchen::Transport::Base::Connection.method_defined?(:download)).must_equal true
      _(Kitchen::Transport::Dokken::Connection.instance_method(:download).owner)
        .must_equal Kitchen::Transport::Base::Connection
    end
  end
end
