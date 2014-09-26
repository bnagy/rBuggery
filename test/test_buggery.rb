#######################################################################
# test_buggery.rb
#
# Test suite for the main library.
#######################################################################

# FIXME this is broken and I don't know why, but I don't care very much

gem 'test-unit'
require 'test/unit'
require 'buggery'

class TC_Buggery < Test::Unit::TestCase
  test("version number is set to expected value") do
    assert_equal('1.1.1', Buggery::VERSION)
  end
end
