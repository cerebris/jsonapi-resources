require 'jsonapi/resources/railtie'
require 'jsonapi/naive_cache'
require 'jsonapi/compiled_json'
require 'jsonapi/basic_resource'
require 'jsonapi/active_relation_resource'
require 'jsonapi/resource'
require 'jsonapi/cached_response_fragment'
require 'jsonapi/response_document'
require 'jsonapi/acts_as_resource_controller'
require 'jsonapi/resource_controller_metal'
require 'jsonapi/resources/version'
require 'jsonapi/configuration'
require 'jsonapi/paginator'
require 'jsonapi/formatter'
require 'jsonapi/routing_ext'
require 'jsonapi/mime_types'
require 'jsonapi/resource_serializer'
require 'jsonapi/exceptions'
require 'jsonapi/error'
require 'jsonapi/error_codes'
require 'jsonapi/request_parser'
require 'jsonapi/processor'
require 'jsonapi/relationship'
require 'jsonapi/include_directives'
require 'jsonapi/operation'
require 'jsonapi/operation_result'
require 'jsonapi/callbacks'
require 'jsonapi/link_builder'
require 'jsonapi/active_relation/adapters/join_left_active_record_adapter'
require 'jsonapi/active_relation/join_manager'
require 'jsonapi/resource_identity'
require 'jsonapi/resource_fragment'
require 'jsonapi/resource_id_tree'
require 'jsonapi/resource_set'
require 'jsonapi/path'
require 'jsonapi/path_segment'

if ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:action_controller_base) do
    require 'jsonapi/resource_controller'
  end
else
  require 'jsonapi/resource_controller'
end
