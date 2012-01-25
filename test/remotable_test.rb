require "test_helper"
require "remotable"
require "support/bespoke"


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
  
  test "should be able to generate paths for composite keys" do
    assert_equal "groups/5/tenants/test",   RemoteWithCompositeKey.remote_path_for([:group_id, :slug], 5, "test")
  end
  
  
  
  test "should create expected finders" do
    assert_equal true, Tenant.respond_to?(:find_by_name)
    assert_equal true, Tenant.respond_to?(:find_by_slug)
    assert_equal true, RemoteWithoutKey.respond_to?(:find_by_id)
    assert_equal true, RemoteWithCompositeKey.respond_to?(:find_by_group_id_and_slug)
  end
  
  
  
  test "should recognize a finder method with a single key" do
    method_details = RemoteWithKey.recognize_remote_finder_method(:find_by_slug)
    assert_not_equal false, method_details
    assert_equal :slug, method_details[:remote_key]
  end
  
  test "should recognize a finder method with a composite key" do
    method_details = RemoteWithCompositeKey.recognize_remote_finder_method(:find_by_group_id_and_slug)
    assert_not_equal false, method_details
    assert_equal [:group_id, :slug], method_details[:remote_key]
  end
  
  
  
  # ========================================================================= #
  # Validating Models                                                         #
  # ========================================================================= #
  
  test "should raise an exception if a remote model does not respond to all class methods" do
    class Example1 < ActiveRecord::Base; set_table_name "tenants"; end
    class RemoteModel1; def self.find_by(*args); end; end
    assert_raise(Remotable::InvalidRemoteModel) { Example1.remote_model RemoteModel1 }
  end
  
  test "should raise an exception if a remote resource does not respond to all instance methods" do
    class Example2 < ActiveRecord::Base; set_table_name "tenants"; end
    class RemoteModel2; def self.new_resource; Object.new; end; end
    assert_raise(Remotable::InvalidRemoteModel) { Example2.remote_model RemoteModel2 }
  end
  
  test "should not raise an exception if remote models are not being validated" do
    Remotable.without_validation do
      class Example4 < ActiveRecord::Base; set_table_name "tenants"; end
      class RemoteModel4; def self.find_by(*args); end; end
      assert_nothing_raised { Example4.remote_model RemoteModel4 }
    end
  end
  
  test "should not raise an exception if a remote model responds to all required methods" do
    class Example3 < ActiveRecord::Base; set_table_name "tenants"; end
    assert_nothing_raised { Example3.remote_model BespokeModel.new }
  end
  
  
end
