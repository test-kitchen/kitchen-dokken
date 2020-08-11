require "spec_helper"

describe "Dokken::Helpers" do
  class TestClass
    include Dokken::Helpers
  end

  # there's not really going to be a real test for insecure_ssh_public_key
  # this is the simplest possible test to check that the testing idea is valid
  describe "#insecure_ssh_public_key" do
    it "is a silly thing" do
      expect(TestClass.new.insecure_ssh_public_key).to be_a String
    end
  end
end
