require "active_record"


class NullTestTenant < ActiveRecord::Base
  self.table_name = "tenants"

  remote_model Remotable::NullRemote
  attr_remote :slug, :name
  remote_key :slug
end
