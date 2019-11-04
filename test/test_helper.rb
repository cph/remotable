require "rubygems"
require "active_support"
require "active_support/core_ext"
require "simplecov"
require "factory_bot"
require "pry"
require "database_cleaner"
require "active_record"
require "factories/tenants"
require "minitest/autorun"
require "minitest/reporters/turn_reporter"

Minitest::Reporters.use! Minitest::Reporters::TurnReporter.new

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "tmp/test.db",
  :verbosity => "quiet")

load File.join(File.dirname(__FILE__), "support", "schema.rb")

DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  setup do
    DatabaseCleaner.start
  end
  teardown do
    DatabaseCleaner.clean
  end
end
