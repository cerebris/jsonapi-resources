source 'https://rubygems.org'

gemspec

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

version = ENV['RAILS_VERSION'] || 'default'

platforms :ruby do
  gem 'pg'
  gem 'mysql2'

  if version.start_with?('4.2', '5.0')
    gem 'sqlite3', '~> 1.3.13'
  else
    gem 'sqlite3', '~> 1.4'
  end
end

case version
when 'master'
  gem 'railties', { git: 'https://github.com/rails/rails.git' }
  gem 'arel', { git: 'https://github.com/rails/arel.git' }
when 'default'
  gem 'railties', '>= 6.0'
else
  gem 'railties', "~> #{version}"
end
