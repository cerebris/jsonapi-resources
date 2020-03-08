module Jsonapi
  class ProcessorGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    class_option :base_processor, type: :string, default: 'JSONAPI::Processor'

    def create_processor
      template_file = File.join(
        'app/processors',
        class_path,
        "#{file_name.singularize}_processor.rb"
      )
      template 'processor.rb.tt', template_file
    end

    private

    def base_processor
      options['base_processor']
    end
  end
end
