require 'active_record'

connection = ActiveRecord::Base.connection

sql = File.read(File.expand_path('../../database/dump.sql', __FILE__))
statements = sql.split(/;$/)
statements.pop  # the last empty statement

statements.each do |statement|
  connection.execute(statement)
end
