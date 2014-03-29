module JSON
  module API
    class Serializer
      include ActiveModel::Serializers::JSON

      def initialize(object, options={})
        @object          = object
      end
    end
  end
end