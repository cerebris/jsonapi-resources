require 'railsapi/resource'
require 'jsonapi/resource_finder'
require 'jsonapi/resource_metadata'

module Railsapi
  class Relationship
    def always_include_linkage_data
      options.fetch(:always_include_linkage_data, false) == true
    end
  end
end

module JSONAPI
  class Resource < Railsapi::Resource
    include JSONAPI::ResourceFinder
    include JSONAPI::ResourceMetadata

    # Override this to return custom links
    # must return a hash, which will be merged with the default { self: 'self-url' } links hash
    # links keys will be not be formatted with the key formatter for the serializer by default.
    # They can however use the serializer's format_key and format_value methods if desired
    # the _options hash will contain the serializer and the serialization_options
    def custom_links(_options)
      {}
    end

    class << self
      def module_path
        if name == 'JSONAPI::Resource'
          ''
        else
          name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').underscore : ''
        end
      end
    end
  end
end
