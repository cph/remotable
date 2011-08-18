require 'rubygems'
require 'rails'
require 'rails/test_help'
require 'active_support/core_ext'
require 'factory_girl'
require 'turn'


require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:",
  :verbosity => "quiet")

load File.join(File.dirname(__FILE__), "support", "schema.rb")


require 'factories/tenants'
