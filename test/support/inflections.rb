# These come from the model definitions and are required for fixture creation as well
# as test running.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
  inflect.uncountable 'file_properties'
end
