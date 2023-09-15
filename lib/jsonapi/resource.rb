require 'jsonapi/callbacks'
require 'jsonapi/configuration'

module JSONAPI
  class Resource
    include ResourceCommon
    load_resource_retrieval_strategy

    @abstract = true
    @immutable = true
    @root = true
  end
end
