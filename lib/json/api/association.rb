module JSON
  module API
    class Association
      def initialize(name, options={})
        @name          = name.to_s
        @options       = options
        @key           = options[:key]
        @primary_key   = options.fetch(:primary_key, 'id')
        # serializer = @options[:serializer]
        # @serializer_from_options = serializer.is_a?(String) ? serializer.constantize : serializer
      end

      def key
        @key
      end

      def class_name
        @class_name
      end

      def primary_key
        @primary_key
      end

      class HasOne < Association
        def initialize(name, options={})
          super
          @class_name    = options.fetch(:class_name, name.capitalize)
          @key ||= "#{name}_id"
        end

        # def serializer_class(object)
        #   serializer_from_options || serializer_from_object(object) || default_serializer
        # end

        # def build_serializer(object, options = {})
        #   options[:_wrap_in_array] = embed_in_root?
        #   super
        # end
      end

      class HasMany < Association
        def initialize(name, options={})
          super
          @class_name    = options.fetch(:class_name, name.to_s.capitalize.singularize)
          @key ||= "#{name.to_s.singularize}_ids"
        end

        # def serializer_class(object)
        #   if use_array_serializer?
        #     ArraySerializer
        #   else
        #     serializer_from_options
        #   end
        # end

        # def options
        #   if use_array_serializer?
        #     { each_serializer: serializer_from_options }.merge! super
        #   else
        #     super
        #   end
        # end

        private

        # def use_array_serializer?
        #   !serializer_from_options ||
        #     serializer_from_options && !(serializer_from_options <= ArraySerializer)
        # end
      end
    end
  end
end
