require_relative "../../spec_helper"

require "kitchen/driver/dokken_version"

describe "Kitchen::Driver::DOKKEN_VERSION" do
  it "is a three-part semantic version" do
    _(Kitchen::Driver::DOKKEN_VERSION).must_match(/\A\d+\.\d+\.\d+\z/)
  end

  # release-please rewrites this constant in place, and the gemspec reads it to
  # build the gem; a value RubyGems cannot parse breaks `rake build`.
  it "is a version RubyGems accepts" do
    _(Gem::Version.correct?(Kitchen::Driver::DOKKEN_VERSION)).must_equal true
  end

  it "matches the version release-please last recorded" do
    manifest = JSON.parse(File.read(File.expand_path("../../../.release-please-manifest.json", __dir__)))

    _(Kitchen::Driver::DOKKEN_VERSION).must_equal manifest["."]
  end
end
