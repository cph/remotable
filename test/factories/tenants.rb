FactoryBot.define do

  factory :tenant do
    sequence(:slug) { |n| "test#{n}" }
    name { "Test" }
    sequence :remote_id
    expires_at { 100.years.from_now }
    nosync { true }
  end

  factory :bespoke_tenant do
    sequence(:slug) { |n| "test#{n}" }
    name { "Test" }
    sequence :remote_id
    expires_at { 100.years.from_now }
    nosync { true }
  end

  factory :null_test_tenant do
    sequence(:slug) { |n| "test#{n}" }
    name { "Test" }
    sequence :remote_id
    expires_at { 100.years.from_now }
    nosync { true }
  end

end

