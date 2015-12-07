module JSONAPI
  class Formatter
    class << self
      def format(arg, options = {})
        arg.to_s
      end

      def unformat(arg)
        arg
      end

      def formatter_for(format)
        formatter_class_name = "#{format.to_s.camelize}Formatter"
        formatter_class_name.safe_constantize
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
      def format(raw_value, options = {})
        super(raw_value, options)
      end

      def unformat(value)
        super(value)
      end

      def value_formatter_for(type)
        formatter_name = "#{type.to_s.camelize}Value"
        formatter_for(formatter_name)
      end
    end
  end
end

class UnderscoredKeyFormatter < JSONAPI::KeyFormatter
end

class CamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.camelize(:lower)
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DasherizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.underscore.dasherize
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DefaultValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value, options = {})
      raw_value
    end
  end
end

class IdValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value, options = {})
      return if raw_value.nil?
      raw_value.to_s
    end
  end
end

class UnderscoredRouteFormatter < JSONAPI::RouteFormatter
end

class CamelizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    def format(route)
      super.camelize(:lower)
    end

    def unformat(formatted_route)
      formatted_route.to_s.underscore
    end
  end
end

class DasherizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    def format(route)
      super.dasherize
    end

    def unformat(formatted_route)
      formatted_route.to_s.underscore
    end
  end
end

##
# Method utilizes the JSONAPI::ResourceSerializer#attribute_hash to serialize the passed in raw value
# which should be serializable by the resource class in the options hash under they :with key.
class NestedAttributeValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value, options = {})
      resource_class = options[:with]
      fail ArgumentError.new('with: must be specified if using format: nested_attribute') unless resource_class
      context = options.fetch(:context, {})
      serializer = JSONAPI::ResourceSerializer.new resource_class

      if raw_value.respond_to? :each
        attrs = []
        raw_value.each do |id|
          resource = resource_class.new(id, context)
          attrs << serializer.send(:attribute_hash, resource)
        end
        attrs
      else
        resource = resource_class.new(raw_value, context)
        serializer.send :attribute_hash, resource
      end
    end

    def unformat(value)
      super(value)
    end
  end
end
