statements = File.read(File.expand_path('../../database/dump.sql', __FILE__)).split(/;$/)
statements.pop  # the last empty statement

statements.each do |statement|
  Sequel::Model.db[statement]
end