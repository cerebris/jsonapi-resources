source 'https://rubygems.org'

gemspec

platforms :ruby do
  gem 'sqlite3', '1.3.10'
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

gem 'coveralls', require: false