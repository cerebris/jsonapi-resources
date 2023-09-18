# frozen_string_literal: true

module JSONAPI
  class ResourceController < ActionController::Base
    include JSONAPI::ActsAsResourceController
  end
end
