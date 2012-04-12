require "test_helper"
require "remotable"
require "support/active_resource"
require "active_resource_simulator"
require "rr"


class ActiveResourceTest < ActiveSupport::TestCase
  include RR::Adapters::TestUnit
  
  test "should make an absolute path and add the format" do
    assert_equal "/api/accounts/by_slug/value.json",   RemoteTenant.expanded_path_for("by_slug/value")
  end
  
  
  
  # ========================================================================= #
  #  Finding                                                                  #
  # ========================================================================= #
  
  test "should be able to find resources by different attributes" do
    new_tenant_slug = "not_found"
    
    assert_equal 0, Tenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a Tenant with the slug #{new_tenant_slug}."
    
    assert_difference "Tenant.count", +1 do
      RemoteTenant.run_simulation do |s|
        s.show(nil, {
          :id => 46,
          :slug => new_tenant_slug,
          :church_name => "Not Found"
        }, :path => "/api/accounts/by_slug/#{new_tenant_slug}.json")
        
        new_tenant = Tenant.find_by_slug(new_tenant_slug)
        assert_not_nil new_tenant, "A remote tenant was not found with the slug #{new_tenant_slug.inspect}"
      end
    end
  end
  
  test "should be able to find resources with a composite key" do
    group_id = 5
    slug = "not_found"
    
    assert_equal 0, RemoteWithCompositeKey.where(:group_id => group_id, :slug => slug).count,
      "There's not supposed to be a Tenant with the group_id #{group_id} and the slug #{slug}."
    
    assert_difference "RemoteWithCompositeKey.count", +1 do
      RemoteTenant.run_simulation do |s|
        s.show(nil, {
          :id => 46,
          :group_id => group_id,
          :slug => slug,
          :church_name => "Not Found"
        }, :path => "/api/accounts/groups/#{group_id}/tenants/#{slug}.json")
        
        new_tenant = RemoteWithCompositeKey.find_by_group_id_and_slug(group_id, slug)
        assert_not_nil new_tenant, "A remote tenant was not found with the group_id #{group_id} and the slug #{slug}."
      end
    end
  end
  
  test "should be able to find resources with the bang method" do
    new_tenant_slug = "not_found2"
    
    assert_equal 0, Tenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a Tenant with the slug #{new_tenant_slug}."
    
    assert_difference "Tenant.count", +1 do
      RemoteTenant.run_simulation do |s|
        s.show(nil, {
          :id => 46,
          :slug => new_tenant_slug,
          :church_name => "Not Found"
        }, :path => "/api/accounts/by_slug/#{new_tenant_slug}.json")
        
        new_tenant = Tenant.find_by_slug!(new_tenant_slug)
        assert_not_nil new_tenant, "A remote tenant was not found with the slug #{new_tenant_slug.inspect}"
      end
    end
  end
  
  test "if a resource is neither local nor remote, raise an exception with the bang method" do
    new_tenant_slug = "not_found3"
    
    assert_equal 0, Tenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a Tenant with the slug #{new_tenant_slug}."
    
    RemoteTenant.run_simulation do |s|
      s.show(nil, nil, :status => 404, :path => "/api/accounts/by_slug/#{new_tenant_slug}.json")
      
      assert_raises ActiveRecord::RecordNotFound do
        Tenant.find_by_slug!(new_tenant_slug)
      end
    end
  end
  
  test "should be able to find resources by different attributes and specify a path" do
    new_tenant_name = "JohnnyG"
    
    assert_equal 0, Tenant.where(:name => new_tenant_name).count,
      "There's not supposed to be a Tenant with the name #{new_tenant_name}."
    
    assert_difference "Tenant.count", +1 do
      RemoteTenant.run_simulation do |s|
        s.show(nil, {
          :id => 46,
          :slug => "not_found",
          :church_name => new_tenant_name
        }, :path => "/api/accounts/by_nombre/#{new_tenant_name}.json")
        
        new_tenant = Tenant.find_by_name(new_tenant_name)
        assert_not_nil new_tenant, "A remote tenant was not found with the name #{new_tenant_name.inspect}"
      end
    end
  end
  
  
  
  # ========================================================================= #
  # Expiration                                                                #
  # ========================================================================= #
  
  test "should not fetch a remote record when a local record is not expired" do
    tenant = Factory(:tenant, :expires_at => 100.years.from_now)
    unexpected_name = "Totally Wonky"
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => unexpected_name
      })
      
      tenant = Tenant.find_by_remote_id(tenant.remote_id)
      assert_not_equal unexpected_name, tenant.name
    end
  end
  
  test "should fetch a remote record when a local record is expired" do
    tenant = Factory(:tenant, :expires_at => 1.year.ago)
    unexpected_name = "Totally Wonky"
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => unexpected_name
      })
      
      tenant = Tenant.find_by_remote_id(tenant.remote_id)
      assert_equal unexpected_name, tenant.name
    end
  end
  
  
  
  # ========================================================================= #
  # Updating                                                                 #
  # ========================================================================= #
  
  test "should update a record remotely when updating one locally" do
    tenant = Factory(:tenant)
    new_name = "Totally Wonky"
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => "totally-wonky",
        :church_name => tenant.name
      })
      
      tenant.nosync = false
      tenant.name = "Totally Wonky"
      assert_equal true, tenant.any_remote_changes?
      
      # Throws an error if save is not called on the remote resource
      mock(tenant.remote_resource).save { true }
      
      tenant.save!
      assert_equal "totally-wonky", tenant.slug, "After updating a record, remote data should be merge"
    end
  end
  
  test "should fail to update a record locally when failing to update one remotely" do
    tenant = Factory(:tenant)
    new_name = "Totally Wonky"
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      s.update(tenant.remote_id, :status => 422, :body => {
        :errors => {:church_name => ["is already taken"]}
      })
      
      tenant.nosync = false
      tenant.name = new_name
      assert_raises(ActiveRecord::RecordInvalid) do
        tenant.save!
      end
      assert_equal ["is already taken"], tenant.errors[:name]
    end
  end
  
  
  
  
  # ========================================================================= #
  # Creating                                                                  #
  # ========================================================================= #
  
  test "should create a record remotely when creating one locally" do
    tenant = Tenant.new({
      :slug => "brand_new",
      :name => "Brand New"
    })
    
    RemoteTenant.run_simulation do |s|
      s.create({
        :id => 143,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      
      tenant.save!
      
      assert_equal true, tenant.remote_resource.persisted?
      assert_equal 143, tenant.remote_id, "After creating a record, remote data should be merge"
    end
  end
  
  test "should fail to create a record locally when failing to create one remotely" do
    tenant = Tenant.new({
      :slug => "brand_new",
      :name => "Brand New"
    })
    
    RemoteTenant.run_simulation do |s|
      s.create({
        :errors => {
          :what => ["ever"],
          :church_name => ["is already taken"]}
      }, :status => 422)
      
      assert_raises(ActiveRecord::RecordInvalid) do
        tenant.save!
      end
      
      assert_equal ["is already taken"], tenant.errors[:name]
    end
  end
  
  test "should create a record locally when fetching a new remote resource" do
    new_tenant_id = 17
    
    assert_equal 0, Tenant.where(:remote_id => new_tenant_id).count,
      "There's not supposed to be a Tenant with the id #{new_tenant_id}."
    
    assert_difference "Tenant.count", +1 do
      RemoteTenant.run_simulation do |s|
        s.show(new_tenant_id, {
          :id => new_tenant_id,
          :slug => "not_found",
          :church_name => "Not Found"
        })
        
        new_tenant = Tenant.find_by_remote_id(new_tenant_id)
        assert_not_nil new_tenant, "A remote tenant was not found with the id #{new_tenant_id.inspect}"
      end
    end
  end
  
  
  
  # ========================================================================= #
  # Destroying                                                                #
  # ========================================================================= #
  
  test "should destroy a record remotely when destroying one locally" do
    tenant = Factory(:tenant)
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      
      # Throws an error if save is not called on the remote resource
      mock(tenant.remote_resource).destroy { true }
      
      tenant.nosync = false
      tenant.destroy
    end
  end
  
  test "should fail to destroy a record locally when failing to destroy one remotely" do
    tenant = Factory(:tenant)
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      
      s.destroy(tenant.remote_id, :status => 500)
      
      tenant.nosync = false
      assert_raises(ActiveResource::ServerError) do
        tenant.destroy
      end
    end
  end
  
  test "should delete a local record when a remote record has been deleted" do
    tenant = Factory(:tenant, :expires_at => 1.year.ago)
    
    assert_difference "Tenant.count", -1 do
      RemoteTenant.run_simulation do |s|
        s.show(tenant.remote_id, nil, :status => 404)
        
        tenant = Tenant.find_by_remote_id(tenant.remote_id)
        assert_equal nil, tenant
      end
    end
  end
  
  
  
end
