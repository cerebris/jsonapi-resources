module JSONAPI
  class ResourceControllerMetal < ActionController::Metal
    MODULES = [
      AbstractController::Rendering,
      ActionController::Rendering,
      ActionController::Renderers::All,
      ActionController::StrongParameters,
      ActionController::ForceSSL,
      ActionController::Instrumentation,
      JSONAPI::ActsAsResourceController
    ].freeze

    # Note, the url_helpers are not loaded. This will prevent links from being generated for resources, and warnings
    # will be emitted. Link support can be added by including `Rails.application.routes.url_helpers`, and links
    # can be disabled, and warning suppressed, for a resource with `exclude_links :default`
    MODULES.each do |mod|
      include mod
    end
  end
end
