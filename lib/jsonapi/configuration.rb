module JSONAPI
  class Configuration
    attr_accessor :json_key_format

    def initialize
      #:underscored, :camelized, :dasherized, or a lambda
      @json_key_format = :underscored
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