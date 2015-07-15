module JSONAPI
  class Error
    attr_accessor :title, :detail, :id, :href, :code, :source, :links, :status

    def initialize(options = {})
      @title          = options[:title]
      @detail         = options[:detail]
      @id             = options[:id]
      @href           = options[:href]
      @code           = if JSONAPI.configuration.use_text_errors
                          TEXT_ERRORS[options[:code]]
                        else
                          options[:code]
                        end
      @source         = options[:source]
      @links          = options[:links]
      @status         = options[:status]
    end
  end
end
