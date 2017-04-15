module Minitest
  module Rollback

    def before_setup
      Sequel::Model.db.synchronize do |conn|
        Sequel::Model.db.send(:add_transaction, conn, {})
        Sequel::Model.db.send(:begin_transaction, conn)
      end
      super
    end

    def after_teardown
      super
      Sequel::Model.db.synchronize {|conn|  Sequel::Model.db.send(:rollback_transaction, conn) }
    end

  end

  class Test
    include Rollback
  end
end