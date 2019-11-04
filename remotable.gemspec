# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "remotable/version"

Gem::Specification.new do |s|
  s.name        = "remotable"
  s.version     = Remotable::VERSION
  s.authors     = ["Robert Lail"]
  s.email       = ["robert.lail@cph.org"]
  s.homepage    = ""
  s.summary     = %q{Binds an ActiveRecord model to a remote resource and keeps the two synchronized}
  s.description = %q{Remotable keeps a locally-stored ActiveRecord synchronized with a remote resource.}

  s.add_dependency "activeresource", ">= 3.2"
  s.add_dependency "activerecord"
  s.add_dependency "activesupport"

  s.add_development_dependency "appraisal"
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest", "~> 5.10.3"
  s.add_development_dependency "minitest-reporters"
  s.add_development_dependency "minitest-reporters-turn_reporter"
  s.add_development_dependency "pry"
  s.add_development_dependency "factory_bot"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "active_resource_simulator"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "rr"
  s.add_development_dependency "database_cleaner"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
