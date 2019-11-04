require "test_helper"
require "remotable"
require "rr"


class UnderstandingTest < ActiveSupport::TestCase
  # This test fails with an Error if `hello` is never called on `o`
  test "I know how rr works :)" do
    o = Object.new
    mock(o).hello('bob', 'jane') { 'hi' }
    assert_equal 'hi', o.hello('bob', 'jane')
  end

end
