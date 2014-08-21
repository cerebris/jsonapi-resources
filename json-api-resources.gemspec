# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi/resources/version'

Gem::Specification.new do |spec|
  spec.name          = 'jsonapi-resources'
  spec.version       = JSONAPI::Resources::VERSION
  spec.authors       = ['Dan Gebhardt', 'Larry Gebhardt']
  spec.email         = ['dan@cerebris.com', 'larry@cerebris.com']
  spec.summary       = %q{Provides JSONAPI support.}
  spec.description   = %q{Provides JSONAPI support.}
  spec.homepage      = 'https://github.com/cerebris/jsonapi-resources'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
end
