require "test_helper"
require "remotable"
require "support/active_resource"


class NoSyncTest < ActiveSupport::TestCase
  
  
  
  test "nosync? should be false by default" do
    assert_equal false, Tenant.new.nosync?
  end
  
  test "nosync? should be true if remotable is turned off globally" do
    Remotable.nosync do
      assert_equal true, Tenant.new.nosync?
      assert_equal true, RemoteWithoutKey.new.nosync?
    end
  end
  
  test "nosync? should be true if remotable is turned off for the model" do
    Tenant.nosync do
      assert_equal true, Tenant.new.nosync?
      assert_equal false, RemoteWithoutKey.new.nosync?
    end
  end
  
  
  
end
