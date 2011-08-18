Factory.define :tenant do |f|
  f.sequence(:slug) { |n| "test#{n}" }
  f.name "Test"
  
  f.active true
  f.expires_at 100.years.from_now
  f.nosync true
end
