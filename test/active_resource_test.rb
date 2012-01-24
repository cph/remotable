require "test_helper"
require "remotable"
require "support/active_resource"


class ActiveResourceTest < ActiveSupport::TestCase
  
  test "should make an absolute path and add the format" do
    assert_equal "/api/accounts/by_slug/value.json",   RemoteTenant.expanded_path_for("by_slug/value")
  end
  
end
