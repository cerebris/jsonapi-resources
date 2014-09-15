module JSONAPI
  class Formatter
    class << self
      def format(arg)
        arg.to_s
      end

      def unformat(arg)
        arg
      end

      if RUBY_VERSION >= '2.0'
        def formatter_for(format)
          key_formatter_class_name = "#{format.to_s.camelize}Formatter"
          Object.const_get key_formatter_class_name if key_formatter_class_name
        end
      else
        def formatter_for(format)
          key_formatter_class_name = "#{format.to_s.camelize}Formatter"
          key_formatter_class_name.safe_constantize if key_formatter_class_name
        end
      end
    end
  end

  class KeyFormatter < Formatter
    class << self
      def format(key)
        super
      end

      def unformat(formatted_key)
        super.to_sym
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
      formatted_key.to_s.underscore.to_sym
    end
  end
end

class DasherizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.dasherize
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore.to_sym
    end
  end
end
