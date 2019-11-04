require "test_helper"
require "remotable"
require "support/null"


class NullRemoteTest < ActiveSupport::TestCase

  # ========================================================================= #
  # Finding                                                                   #
  # ========================================================================= #

  test "should do nothing if a tenant is expired" do
    tenant = create(:null_test_tenant, expires_at: 2.days.ago)
    result = NullTestTenant.find_by_slug(tenant.slug)
    assert_equal tenant, result
  end

  test "should raise an exception with the bang method if resource isn't found locally" do
    new_tenant_slug = "not_found3"
    assert_equal 0, NullTestTenant.where(:slug => new_tenant_slug).count,
      "There's not supposed to be a NullTestTenant with the slug #{new_tenant_slug}."

    assert_raises ActiveRecord::RecordNotFound do
      NullTestTenant.find_by_slug!(new_tenant_slug)
    end
  end



  # ========================================================================= #
  # Updating                                                                 #
  # ========================================================================= #

  test "should update a record locally without any interference" do
    tenant = create(:null_test_tenant)
    new_name = "Totally Wonky"

    tenant.name = new_name
    tenant.save!
  end



  # ========================================================================= #
  # Creating                                                                  #
  # ========================================================================= #

  test "should create a record locally without any interference" do
    tenant = NullTestTenant.create!({
      :slug => "brand_new",
      :name => "Brand New"
    })
    assert_not_nil tenant.remote_resource
  end



  # ========================================================================= #
  # Destroying                                                                #
  # ========================================================================= #

  test "should destroy a record locally without any interference" do
    tenant = create(:null_test_tenant)
    tenant.nosync = false
    tenant.destroy
  end



end
