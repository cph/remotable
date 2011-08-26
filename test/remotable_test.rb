require "test_helper"
require "remotable"
require "support/active_resource"
require "active_resource_simulator"


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
    assert_equal "/api/accounts/by_slug/value.json",   RemoteTenant.path_for(:slug, "value")
    assert_equal "/api/accounts/by_nombre/value.json", RemoteTenant.path_for(:name, "value")
  end
  
  
  
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
  
  
  
  test "should update a record remotely when updating one locally" do
    tenant = Factory(:tenant)
    new_name = "Totally Wonky"
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      s.update(tenant.remote_id)
      
      tenant.nosync = false
      tenant.name = "Totally Wonky"
      assert_equal true, tenant.any_remote_changes?
      
      tenant.save!
      
      pending "Not sure how to test that an update happened"
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
  
  
  
  test "should destroy a record remotely when destroying one locally" do
    tenant = Factory(:tenant)
    
    RemoteTenant.run_simulation do |s|
      s.show(tenant.remote_id, {
        :id => tenant.remote_id,
        :slug => tenant.slug,
        :church_name => tenant.name
      })
      s.destroy(tenant.remote_id)
      
      tenant.nosync = false
      tenant.destroy
      
      pending # how do I check for this?
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
  
  
  
end
