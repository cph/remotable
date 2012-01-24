require "test_helper"
require "remotable"


class RemotableTest < ActiveSupport::TestCase
  
  
  test "should consider :id to be the remote key if none is specified" do
    assert_equal :id,         RemoteWithoutKey.remote_key
    assert_equal :remote_id,  RemoteWithoutKey.local_key
  end
  
  test "should use a different remote_key if one is supplied" do
    assert_equal :slug, RemoteWithKey.remote_key
    assert_equal :slug, RemoteWithKey.local_key
  end
  
  test "should be able to generate paths for with different attributes" do
    assert_equal "by_slug/value",   Tenant.remote_path_for(:slug, "value")
    assert_equal "by_nombre/value", Tenant.remote_path_for(:name, "value")
  end
  
  
end
