module JSONAPI
  class Formatter
    class << self
      def format(arg)
        arg.to_s
      end

      def unformat(arg)
        arg
      end

      @@format_to_formatter_cache = JSONAPI::NaiveCache.new do |format|
        "#{format.to_s.camelize}Formatter".safe_constantize
      end

      def formatter_for(format)
        @@format_to_formatter_cache.calc(format)
      end
    end
  end

  class KeyFormatter < Formatter
    class << self
      def format(key)
        super
      end

      def unformat(formatted_key)
        super
      end
    end
  end

  class RouteFormatter < Formatter
    class << self
      def format(route)
        super
      end

      def unformat(formatted_route)
        super
      end
    end
  end

  class ValueFormatter < Formatter
    class << self
      def format(raw_value)
        super(raw_value)
      end

      def unformat(value)
        super(value)
      end

      @@value_type_to_formatter_cache = JSONAPI::NaiveCache.new do |type|
        "#{type.to_s.camelize}ValueFormatter".safe_constantize
      end

      def value_formatter_for(type)
        @@value_type_to_formatter_cache.calc(type)
      end
    end
  end
end

class UnderscoredKeyFormatter < JSONAPI::KeyFormatter
end

class CamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    @@format_cache = JSONAPI::NaiveCache.new do |key|
      key.to_s.camelize(:lower)
    end
    @@unformat_cache = JSONAPI::NaiveCache.new do |formatted_key|
      formatted_key.to_s.underscore
    end

    def format(key)
      @@format_cache.calc(key)
    end

    def unformat(formatted_key)
      @@unformat_cache.calc(formatted_key)
    end
  end
end

class DasherizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    @@format_cache = JSONAPI::NaiveCache.new do |key|
      key.to_s.underscore.dasherize
    end
    @@unformat_cache = JSONAPI::NaiveCache.new do |formatted_key|
      formatted_key.to_s.underscore
    end

    def format(key)
      @@format_cache.calc(key)
    end

    def unformat(formatted_key)
      @@unformat_cache.calc(formatted_key)
    end
  end
end

class DefaultValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value
    end
  end
end

class IdValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      return if raw_value.nil?
      raw_value.to_s
    end
  end
end

class UnderscoredRouteFormatter < JSONAPI::RouteFormatter
end

class CamelizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    @@format_cache = JSONAPI::NaiveCache.new do |route|
      route.to_s.camelize(:lower)
    end
    @@unformat_cache = JSONAPI::NaiveCache.new do |formatted_route|
      formatted_route.to_s.underscore
    end

    def format(route)
      @@format_cache.calc(route)
    end

    def unformat(formatted_route)
      @@unformat_cache.calc(formatted_route)
    end
  end
end

class DasherizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    @@format_cache = JSONAPI::NaiveCache.new do |route|
      route.to_s.dasherize
    end
    @@unformat_cache = JSONAPI::NaiveCache.new do |formatted_route|
      formatted_route.to_s.underscore
    end

    def format(route)
      @@format_cache.calc(route)
    end

    def unformat(formatted_route)
      @@unformat_cache.calc(formatted_route)
    end
  end
end
