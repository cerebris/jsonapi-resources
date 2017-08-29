module JSONAPI
  module ActsAsResourceController
    # Will serve resources custom actions
    #
    # @return [View] Renders JSONAPI response
    def custom_actions
      process_request
    end
  end
end
