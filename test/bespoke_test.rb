require "test_helper"
require "remotable"
require "support/bespoke"
require "rr"


class BespokeTest < ActiveSupport::TestCase
  include RR::Adapters::TestUnit
  
  
  teardown do
    def model.new_resource
      BespokeResource.new
    end
    def model.find_by(remote_attr, value)
      nil
    end
  end
  
  
  
  # ========================================================================= #
  # Finding                                                                   #
  # ========================================================================= #
  
  test "should be able to find resources by different attributes" do
    new_tenant_slug = "not_found"
    assert_equal 0, BespokeTenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a BespokeTenant with the slug #{new_tenant_slug}."
    
    def model.find_by(attribute, value)
      BespokeResource.new(:slug => value)
    end
    
    new_tenant = BespokeTenant.find_by_slug(new_tenant_slug)
    assert_not_nil new_tenant, "A remote @tenant was not found with the slug #{new_tenant_slug.inspect}"
  end
  
  test "should create a record locally when fetching a new remote resource" do
    new_tenant_slug = "17"
    assert_equal 0, BespokeTenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a BespokeTenant with the slug #{new_tenant_slug}."
    
    def model.find_by(attribute, value)
      BespokeResource.new(:slug => value)
    end
    
    assert_difference "BespokeTenant.count", +1 do
      new_tenant = BespokeTenant.find_by_slug(new_tenant_slug)
      assert_not_nil new_tenant, "A remote tenant was not found with the id #{new_tenant_slug.inspect}"
    end
  end
  
  test "if a resource is neither local nor remote, raise an exception with the bang method" do
    new_tenant_slug = "not_found3"
    assert_equal 0, BespokeTenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a BespokeTenant with the slug #{new_tenant_slug}."
    
    assert_raises ActiveRecord::RecordNotFound do
      BespokeTenant.find_by_slug!(new_tenant_slug)
    end
  end
  
  
  
  # ========================================================================= #
  # Updating                                                                 #
  # ========================================================================= #
  
  test "should update a record remotely when updating one locally" do
    @tenant = Factory(:bespoke_tenant)
    new_name = "Totally Wonky"
    
    # RemoteTenant.run_simulation do |s|
    #   s.show(@tenant.remote_id, {
    #     :id => @tenant.remote_id,
    #     :slug => @tenant.slug,
    #     :church_name => @tenant.name
    #   })
    #   s.update(@tenant.remote_id)
    #   
    #   @tenant.nosync = false
    #   @tenant.name = "Totally Wonky"
    #   assert_equal true, @tenant.any_remote_changes?
    #   
    #   @tenant.save!
    #   
    #   pending "Not sure how to test that an update happened"
    # end
  end
  
  test "should fail to update a record locally when failing to update one remotely" do
    @tenant = Factory(:bespoke_tenant, :nosync => false)
    
    def model.find_by(attribute, value)
      BespokeResource.new(attribute => value)
    end
    
    def resource.save
      false
    end
    
    def resource.errors
      {:name => ["is already taken"]}
    end
    
    @tenant.name = "Totally Wonky"
    assert_raises(ActiveRecord::RecordInvalid) do
      @tenant.save!
    end
    assert_equal ["is already taken"], @tenant.errors[:name]
  end
  
  
  
  
  # ========================================================================= #
  # Creating                                                                  #
  # ========================================================================= #
  
  test "should create a record remotely when creating one locally" do
    @tenant = BespokeTenant.new({
      :slug => "brand_new",
      :name => "Brand New"
    })
    
    assert_nil @tenant.remote_resource
    @tenant.save!
    assert_not_nil @tenant.remote_resource
  end
  
  test "should fail to create a record locally when failing to create one remotely" do
    @tenant = BespokeTenant.new({
      :slug => "brand_new",
      :name => "Brand New"
    })
    
    def model.new_resource
      resource = BespokeResource.new
      def resource.save; false; end
      def resource.errors; {:name => ["is already taken"]}; end
      resource
    end
    
    assert_raises(ActiveRecord::RecordInvalid) do
      @tenant.save!
    end
    
    assert_equal ["is already taken"], @tenant.errors[:name]
  end
  
  
  
  # ========================================================================= #
  # Destroying                                                                #
  # ========================================================================= #
  
  test "should destroy a record remotely when destroying one locally" do
    @tenant = Factory(:bespoke_tenant, :nosync => false)
    mock(resource).destroy { true }
    @tenant.destroy
  end
  
  test "should fail to destroy a record locally when failing to destroy one remotely" do
    @tenant = Factory(:bespoke_tenant, :nosync => false)
    mock(resource).destroy { raise StandardError }
    assert_raises(StandardError) do
      @tenant.destroy
    end
  end
  
  test "should delete a local record when a remote record has been deleted" do
    @tenant = Factory(:bespoke_tenant, :expires_at => 1.year.ago)
    
    def model.find_by(remote_attr, value)
      nil
    end
    
    assert_difference "BespokeTenant.count", -1 do
      @tenant = BespokeTenant.find_by_slug(@tenant.slug)
      assert_equal nil, @tenant
    end
  end
  
  
  
private
  
  def model
    BespokeTenant.remote_model
  end
  
  def resource
    @tenant.remote_resource
  end
  
end
