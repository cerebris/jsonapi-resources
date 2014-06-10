module JSON
  module API
    class Error
      def initialize(options={})
        @title          = options[:title]
        @detail         = options[:detail]
        @id             = options[:id]
        @href           = options[:href]
        @code           = options[:code]
        @path           = options[:path]
        @links          = options[:links]
      end

      def to_json
        error_hash = {}
        error_hash[:title] = @title unless @title.nil?
        error_hash[:detail] = @detail unless @detail.nil?
        error_hash[:id] = @id unless @id.nil?
        error_hash[:href] = @href unless @href.nil?
        error_hash[:code] = @code unless @code.nil?
        error_hash[:path] = @path unless @path.nil?
        error_hash[:links] = @links unless @links.nil? || @links.blank?
        error_hash
      end
    end
  end
end