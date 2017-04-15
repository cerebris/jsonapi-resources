module Minitest
  module Rollback

    def before_setup
      ActiveRecord::Base.connection.begin_transaction joinable: false
      super
    end

    def after_teardown
      super
      conn = ActiveRecord::Base.connection
      conn.rollback_transaction if conn.transaction_open?
      ActiveRecord::Base.clear_active_connections!
    end

  end

  class Test
    include Rollback
  end
end