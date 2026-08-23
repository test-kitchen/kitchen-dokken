require_relative "spec_helper"

require "docker"

# A safety net nobody has watched fail is indistinguishable from no safety
# net. `spec_helper.rb` asks mocha to reject stubs for methods that do not
# exist, and mocha's `check` silently treats an unrecognised value as
# `:allow` -- so `:prohibit`, `:strict` or a future rename would leave the
# setting looking configured while enforcing nothing, and every other spec in
# this suite would carry on passing.
#
# These two examples deliberately do the wrong thing and require that it be
# caught.
describe "mocha strict stubbing" do
  it "is configured to prevent stubbing a non-existent method" do
    _(Mocha.configuration.stubbing_non_existent_method).must_equal :prevent
  end

  # `Docker::Image` has `exist?`, not `exist`. Stubbing the typo is exactly
  # the mistake the setting exists to catch, and it must raise at stub time.
  it "raises when a spec stubs a docker-api method that does not exist" do
    _ { ::Docker::Image.stubs(:exist) }.must_raise Mocha::StubbingError
  end

  it "still allows stubbing a method that does exist" do
    ::Docker::Image.stubs(:exist?).returns(true)

    _(::Docker::Image.exist?("anything")).must_equal true
  end
end
