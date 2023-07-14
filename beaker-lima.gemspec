# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'beaker-lima/version'

Gem::Specification.new do |s|
  s.name        = 'beaker-lima'
  s.version     = BeakerLima::VERSION
  s.summary     = 'Lima hypervisor for Beaker acceptance testing framework'
  s.description = 'Allows running Beaker tests using Lima'
  s.authors     = ['Yury Bushmelev', 'Vox Pupuli']
  s.email       = 'voxpupuli@groups.io'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/voxpupuli/beaker-lima'
  s.license     = 'Apache-2.0'

  s.required_ruby_version = '>= 2.7'

  s.add_development_dependency 'fakefs', '>= 1.3', '< 3.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'voxpupuli-rubocop', '~> 2.0'

  s.add_runtime_dependency 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
  s.add_runtime_dependency 'beaker', '~> 5.0'
end
