require 'rails/generators'

module Jsonapi
  class ResourceGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    class_option :base_resource, type: :string, default: 'JSONAPI::Resource'
    class_option :controller, type: :boolean, default: false, desc: "Create a controller."
    class_option :processor, type: :boolean, default: false, desc: "Create a processor."
    class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."

    hook_for :controller do |controller|
      invoke controller, [ file_path ]
    end

    hook_for :processor do |processor|
      invoke processor, [ file_path ]
    end

    def create_resource
      template_file = File.join(
        'app/resources',
        class_path,
        "#{file_name.singularize}_resource.rb"
      )
      template 'resource.rb.tt', template_file
    end

    private

    def base_resource
      options['base_resource']
    end
  end
end
