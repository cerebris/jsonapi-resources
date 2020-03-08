module Jsonapi
  class ControllerGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    class_option :base_controller, type: :string, default: 'JSONAPI::ResourceController'
    class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."

    def create_resource
      template_file = File.join(
        'app/controllers',
        class_path,
        "#{file_name.pluralize}_controller.rb"
      )
      template 'controller.rb.tt', template_file
    end

    def add_routes
      return if options[:skip_routes]
      route generate_routing_code
    end

    private

    def base_controller
      options['base_controller']
    end

    # This method creates nested route entry for namespaced resources.
    # For eg. rails g controller foo/bar/baz index show
    # Will generate -
    # namespace :foo do
    #   namespace :bar do
    #     get 'baz/index'
    #     get 'baz/show'
    #   end
    # end
    def generate_routing_code
      depth = 0
      lines = []

      # Create 'namespace' ladder
      # namespace :foo do
      #   namespace :bar do
      regular_class_path.each do |ns|
        lines << indent("namespace :#{ns} do\n", depth * 2)
        depth += 1
      end

      lines << indent(%{jsonapi_resources :#{file_name.pluralize}\n}, depth * 2)

      # Create `end` ladder
      #   end
      # end
      until depth.zero?
        depth -= 1
        lines << indent("end\n", depth * 2)
      end

      lines.join
    end
  end
end
