require 'jsonapi/callbacks'
require 'jsonapi/configuration'

module JSONAPI
  class Resource
    include ResourceCommon
    load_resource_retrieval_strategy
    root_resource
    abstract
    immutable
  end
end
