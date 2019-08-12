TestApp.class_eval do
  config.active_record.schema_format = :none

  if Rails::VERSION::MAJOR >= 5
    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
    config.active_record.belongs_to_required_by_default = false
  end
end
