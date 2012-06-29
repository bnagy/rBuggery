#######################################################################
# test_buggery.rb
#
# Test suite for the main library.
#######################################################################
require 'rubygems'
gem 'test-unit'
require 'test/unit'
require 'buggery'

class TC_Buggery < Test::Unit::TestCase
  test "version number is set to expected value" do
    assert_equal('0.5.0', Buggery::VERSION)
  end
end
