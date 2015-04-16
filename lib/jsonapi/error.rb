module JSONAPI
  class Error

    attr_accessor :title, :detail, :id, :href, :code, :path, :links, :status

    def initialize(options={})
      @title          = options[:title]
      @detail         = options[:detail]
      @id             = options[:id]
      @href           = options[:href]
      @code           = if JSONAPI.configuration.use_text_errors
                          TEXT_ERRORS[options[:code]]
                        else
                          options[:code]
                        end
      @path           = options[:path]
      @links          = options[:links]
      @status         = options[:status]
    end
  end
end
