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
  
  test "nosync? should be false if syncing is resumed temporarily on a model that prevents it by default" do
    Tenant.nosync!
    assert_equal true, Tenant.new.nosync?
    Tenant.nosync(false) do
      assert_equal false, Tenant.new.nosync?
    end
    assert_equal true, Tenant.new.nosync?
  end
  
  
  
  # ========================================================================= #
  # Finding                                                                   #
  # ========================================================================= #
  
  test "should do nothing if a tenant is expired" do
    tenant = Factory(:tenant, :expires_at => 1.year.ago)
    
    Remotable.nosync do
      result = Tenant.find_by_remote_id(tenant.remote_id)
      assert_equal tenant, result
    end
  end
  
  
  
end
