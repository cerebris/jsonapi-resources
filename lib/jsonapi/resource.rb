require 'jsonapi/callbacks'
require 'jsonapi/configuration'

module JSONAPI
  class Resource
    include ResourceCommon
    root_resource
    abstract
    immutable
  end
end
