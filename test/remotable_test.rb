require "test_helper"
require "remotable"
require "support/bespoke"
require "support/concurrently"


class RemotableTest < ActiveSupport::TestCase



  # ========================================================================= #
  #  Keys                                                                     #
  # ========================================================================= #

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
    assert_equal "groups/5/tenants/test",   RemoteWithCompositeKey.remote_path_for([:group_id, :slug], [5, "test"])
  end



  # ========================================================================= #
  #  Temporary remote models                                                  #
  # ========================================================================= #

  test "should support temporary models" do
    assert_nil BespokeTenant.find_by_slug("404")
    assert_not_nil BespokeTenant.with_remote_model(BespokeModel2.new) { BespokeTenant.find_by_slug("404") }
    assert_nil BespokeTenant.find_by_slug("405")
  end

  test "should support temporary models and chainable syntax" do
    assert_nil BespokeTenant.find_by_slug("404")
    assert_not_nil BespokeTenant.with_remote_model(BespokeModel2.new).find_by_slug("404")
    assert_nil BespokeTenant.find_by_slug("405")
  end

  test "should support setting remote_model to nil" do
    Tenant.with_remote_model(nil) do
      Tenant.remote_model
      assert_nil Tenant.remote_model, "remote_model didn't get set to nil"
      Tenant.create!(:name => "Test 1", :slug => "test-1")
      assert_not_nil Tenant.find_by_name("Test 1"), "new tenant was not found"
    end
  end

  test "should support temporary models in a threaded environment" do
    first_slug = "404"
    second_slug = "405"

    afterwards do
      BespokeTenant.where(slug: [ first_slug, second_slug ]).delete_all
    end

    concurrently do
      assert_nil BespokeTenant.find_by_slug(first_slug), "Expected not to find the first model initially"
      # If the second thread attempts the above lookup after the first thread
      # has already run the lookup below, the lookup above will find the
      # _local_ record in the database, which is not what this test is trying
      # to test -- whether we successfully switch models temporarily in a
      # mult-threaded situation. The extra sleep call ensures that the first
      # call completes on both before moving on to the rest of the lookups.
      sleep rand
      assert_not_nil BespokeTenant.with_remote_model(BespokeModel2.new) {
        BespokeTenant.find_by_slug(first_slug)
        sleep rand
      }, "Expected to find the first model with the temporary tenant"
      assert_nil BespokeTenant.find_by_slug(second_slug), "Expected not to find the second model when searching with the original model again"
    end
  end



  # ========================================================================= #
  #  Edge cases                                                               #
  #                                                                           #
  #  Suppose some records of a table are remoted and others aren't.           #
  #  If a record is saved which is local-only, it's remote primary key        #
  #  isn't stored. If this record is expired, then make sure that             #
  #  Remotable doesn't break when it tries to look up a remote record         #
  #  with a nil key.                                                          #
  # ========================================================================= #

  test "should not break when refreshing a record which does not have a foreign key" do
    tenant = Tenant.nosync { Tenant.create!(
      :name => "Test 1",
      :slug => "test-1",
      :remote_id => nil,
      :expires_at => 1.day.ago ) }
    assert_nil tenant.remote_id

    # Fetching this tenant, Remotable will want to
    # refresh it, but it shouldn't because it can't.
    assert_not_nil Tenant.where(:slug => "test-1").first, "A tenant with the slug \"test-1\" was not found"
  end

  test "should not break when updating a record which does not have a foreign key" do
    tenant = Tenant.nosync { Tenant.create!(
      :name => "Test 1",
      :slug => "test-1",
      :remote_id => nil ) }
    assert_nil tenant.remote_id

    # Updating this tenatn, Remotable will want to
    # sync it, but it shouldn't because it can't.
    assert_equal true, tenant.update(name: "Test 2"), "The tenant was not updated (errors: #{tenant.errors.full_messages.join(", ")})"
  end



  # ========================================================================= #
  #  Finders                                                                  #
  # ========================================================================= #

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
  #  Validating Models                                                        #
  # ========================================================================= #

  test "should raise an exception if a remote model does not respond to all class methods" do
    class Example1 < ActiveRecord::Base; self.table_name = "tenants"; end
    class RemoteModel1; def self.find_by(*args); end; end
    assert_raise(Remotable::InvalidRemoteModel) { Example1.remote_model RemoteModel1 }
  end

  test "should raise an exception if a remote resource does not respond to all instance methods" do
    class Example2 < ActiveRecord::Base; self.table_name = "tenants"; end
    class RemoteModel2; def self.new_resource; Object.new; end; end
    assert_raise(Remotable::InvalidRemoteModel) { Example2.remote_model RemoteModel2 }
  end

  test "should not raise an exception if remote models are not being validated" do
    Remotable.without_validation do
      class Example4 < ActiveRecord::Base; self.table_name = "tenants"; end
      class RemoteModel4; def self.find_by(*args); end; end
      assert_nothing_raised { Example4.remote_model RemoteModel4 }
    end
  end

  test "should not raise an exception if a remote model responds to all required methods" do
    class Example3 < ActiveRecord::Base; self.table_name = "tenants"; end
    assert_nothing_raised { Example3.remote_model BespokeModel.new }
  end



  # ========================================================================= #
  # ActiveRecordExtender                                                      #
  # ========================================================================= #

  test "should extend an ActiveRecord subclass with Nosync class methods" do
    class Example5 < ActiveRecord::Base; self.table_name = "tenants"; end
    Example5.remote_model BespokeModel.new
    # Method is _only_ on the class version
    assert Example5.respond_to?(:unsafe_nosync!)
  end


end
