source 'https://rubygems.org'

gemspec

platforms :ruby do
  gem 'sqlite3', '1.3.10'
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

version = ENV['RAILS_VERSION'] || 'default'

case version
when 'master'
  gem 'arel', git: 'https://github.com/rails/arel.git'
  gem 'railties', git: 'https://github.com/rails/rails.git'
when 'default'
  gem 'railties', '>= 5.0'
else
  gem 'railties', "~> #{version}"
end
