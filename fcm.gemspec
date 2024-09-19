# -*- encoding: utf-8 -*-

$:.push File.expand_path('../lib', __FILE__)

REPOSITORY_URI = 'https://github.com/decision-labs/fcm'

Gem::Specification.new do |s|
  s.name        = 'fcm'
  s.version     = '2.0.0'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Kashif Rasul', 'Shoaib Burq']
  s.email       = ['kashif@decision-labs.com', 'shoaib@decision-labs.com']
  s.homepage    = REPOSITORY_URI
  s.summary     = %q{Reliably deliver messages and notifications via FCM}
  s.description = %q{fcm provides ruby bindings to Firebase Cloud Messaging (FCM) a cross-platform messaging solution that lets you reliably deliver messages and notifications at no cost to Android, iOS or Web browsers.}
  s.license     = 'MIT'
  s.metadata    = {
    'homepage_uri' => REPOSITORY_URI,
    'changelog_uri' => "#{REPOSITORY_URI}/blob/master/CHANGELOG.md",
    'source_code_uri' => REPOSITORY_URI
  }

  s.required_ruby_version = '>= 2.4.0'

  s.files = `git ls-files`.split('\n')
  s.test_files = `git ls-files -- {test,spec,features}/*`.split('\n')
  s.executables = `git ls-files -- bin/*`.split('\n').map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency('faraday', '>= 1.0.0', '< 3.0')
  s.add_runtime_dependency('googleauth', '~> 1')
end
