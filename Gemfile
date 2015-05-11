source 'https://rubygems.org'

gemspec

platforms :ruby do
  gem 'sqlite3', '1.3.10'
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

version = ENV['RAILS_VERSION'] || 'default'
rails = case version
        when 'master'
          {:github => 'rails/rails'}
        when 'default'
            '>= 4.2'
        else
          "~> #{version}"
        end
gem 'rails', rails

group :development do
  gem 'byebug'
end
