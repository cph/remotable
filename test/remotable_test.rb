require 'test_helper'
require 'remotable'
require 'support/active_resource'
require 'active_resource_simulator'


class RemotableTest < ActiveSupport::TestCase
  
  
  test "should create a record locally when fetching a new remote resource" do
    new_tenant_slug = "not_found"
    
    assert_equal 0, Tenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a Tenant with the subdomain #{new_tenant_slug}."
    
    assert_difference "Tenant.count", +1 do
      Tenant::RemoteTenant.run_simulation do |s|
        attrs = {
          :id => 1,
          :slug => "not_found",
          :church_name => "Not Found"
        }
        
        s.show(nil, attrs, :path => "/api/accounts/by_slug/#{attrs[:slug]}.json")
        
        Tenant.find_by_slug(new_tenant_slug)
      end
    end
  end
  
  
  
  test "should not fetch a remote record when a local record is not expired" do
    tenant = Factory(:tenant, :expires_at => 100.years.from_now)
    unexpected_name = "Totally Wonky"
    
    Tenant::RemoteTenant.run_simulation do |s|
      attrs = {
        :id => tenant.id,
        :slug => tenant.slug,
        :church_name => unexpected_name
      }
      
      s.show(nil, attrs, :path => "/api/accounts/by_slug/#{attrs[:slug]}.json")
      
      tenant = Tenant.find_by_slug(tenant.slug)
      assert_not_equal unexpected_name, tenant.name
    end
  end
  
  
  
  test "should fetch a remote record when a local record is expired" do
    tenant = Factory(:tenant, :expires_at => 1.year.ago)
    unexpected_name = "Totally Wonky"
    
    Tenant::RemoteTenant.run_simulation do |s|
      attrs = {
        :id => tenant.id,
        :slug => tenant.slug,
        :church_name => unexpected_name
      }
      
      s.show(nil, attrs, :path => "/api/accounts/by_slug/#{attrs[:slug]}.json")
      
      tenant = Tenant.find_by_slug(tenant.slug)
      assert_equal unexpected_name, tenant.name
    end
  end
  
  
  
  test "should delete a local record when a remote record has been deleted" do
    tenant = Factory(:tenant, :expires_at => 1.year.ago)
    
    assert_difference "Tenant.count", -1 do
      Tenant::RemoteTenant.run_simulation do |s|
        
        s.show(nil, nil, :path => "/api/accounts/by_slug/#{tenant.slug}.json", :status => 404)
        
        tenant = Tenant.find_by_slug(tenant.slug)
        assert_equal nil, tenant
      end
    end
  end
  
  
  
  test "should update a record remotely when updating one locally" do
    tenant = Factory(:tenant)
    new_name = "Totally Wonky"
    
    Tenant::RemoteTenant.run_simulation do |s|
      s.show(nil, {
        :id => tenant.id,
        :slug => tenant.slug,
        :church_name => tenant.name
        }, :path => "/api/accounts/by_slug/#{tenant.slug}.json")
      
      s.update(tenant.id)
      
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
    
    Tenant::RemoteTenant.run_simulation do |s|
      s.show(nil, {
          :id => tenant.id,
          :slug => tenant.slug,
          :church_name => tenant.name
        }, :path => "/api/accounts/by_slug/#{tenant.slug}.json")
      
      s.update(tenant.id, :status => 422, :body => {
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
    
    Tenant::RemoteTenant.run_simulation do |s|
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
    
    Tenant::RemoteTenant.run_simulation do |s|
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
    
    Tenant::RemoteTenant.run_simulation do |s|
      s.show(nil, {
          :id => tenant.id,
          :slug => tenant.slug,
          :church_name => tenant.name
        }, :path => "/api/accounts/by_slug/#{tenant.slug}.json")
      
      s.destroy(tenant.id)
      
      tenant.nosync = false
      tenant.destroy
      
      pending # how do I check for this?
    end
  end
  
  test "should fail to destroy a record locally when failing to destroy one remotely" do
    tenant = Factory(:tenant)
    
    Tenant::RemoteTenant.run_simulation do |s|
      s.show(nil, {
          :id => tenant.id,
          :slug => tenant.slug,
          :church_name => tenant.name
        }, :path => "/api/accounts/by_slug/#{tenant.slug}.json")
      
      s.destroy(tenant.id, :status => 500)
      
      tenant.nosync = false
      assert_raises(ActiveResource::ServerError) do
        tenant.destroy
      end
    end
  end
  
  
  
end
