# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "fcm"
  s.version     = "0.0.2"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Kashif Rasul", "Shoaib Burq"]
  s.email       = ["kashif@spacialdb.com", "shoaib@spacialdb.com"]
  s.homepage    = "https://github.com/spacialdb/fcm"
  s.summary     = %q{Reliably deliver messages and notifications via FCM}
  s.description = %q{fcm provides ruby bindings to Firebase Cloud Messaging (FCM) a cross-platform messaging solution that lets you reliably deliver messages and notifications at no cost to Android, iOS or Web browsers.}
  s.license     = "MIT"

  s.required_ruby_version     = '>= 2.0.0'

  s.rubyforge_project = "fcm"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('httparty')
  s.add_dependency('json')
end
