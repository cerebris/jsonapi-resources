source 'https://rubygems.org'

gemspec

platforms :ruby do
  # sqlite3 1.3.9 does not work with rubinius 2.2.5:
  # https://github.com/sparklemotion/sqlite3-ruby/issues/122
  gem 'sqlite3', '1.3.8'
end

platforms :mri do
  gem 'coveralls', require: false
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

version = ENV['RAILS_VERSION'] || '4.0.4'
rails = case version
        when 'master'
          {:github => 'rails/rails'}
        else
          "~> #{version}"
        end
gem 'rails', rails

group :test do
  gem 'minitest', '~> 4.7.5'
  #gem 'minitest-rails'
  gem 'minitest-spec-rails'
  gem 'simplecov', :require => false

  gem 'minitest-reporters'

  # guard
  gem 'guard'
  gem 'guard-minitest'
  gem 'turn'
  gem 'rb-fsevent', '~> 0.9.1'
end
