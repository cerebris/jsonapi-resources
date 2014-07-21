module JSON
  module API
    class Error

      attr_accessor :title, :detail, :id, :href, :code, :path, :links, :status

      def initialize(options={})
        @title          = options[:title]
        @detail         = options[:detail]
        @id             = options[:id]
        @href           = options[:href]
        @code           = options[:code]
        @path           = options[:path]
        @links          = options[:links]
        @status         = options[:status]
      end
    end
  end
end