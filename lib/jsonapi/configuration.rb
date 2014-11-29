require 'jsonapi/formatter'

module JSONAPI
  class Configuration
    attr_reader :json_key_format, :key_formatter, :allowed_request_params

    def initialize
      #:underscored_key, :camelized_key, :dasherized_key, or custom
      self.json_key_format = :underscored_key
      self.allowed_request_params = [:include, :fields, :format, :controller, :action, :sort]
    end

    def json_key_format=(format)
      @json_key_format = format
      @key_formatter = JSONAPI::Formatter.formatter_for(format)
    end

    def allowed_request_params=(allowed_request_params)
      @allowed_request_params = allowed_request_params
    end
  end

  class << self
    attr_accessor :configuration
  end

  @configuration ||= Configuration.new

  def self.configure
    yield(@configuration)
  end
end