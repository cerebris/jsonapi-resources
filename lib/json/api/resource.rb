module JSON
  module API
    class Resource
      def fetchable(keys)
        keys
      end

      def updateable(keys)
        keys
      end

      def creatable(keys)
        keys
      end
    end
  end
end
