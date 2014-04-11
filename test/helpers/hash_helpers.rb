module Helpers
  module HashHelpers
    def assert_hash_contains(exp, act, msg = nil)
      msg = message(msg, '') { diff exp, act }
      assert(matches_hash?(exp, act), msg)
    end

    def assert_hash_equals(exp, act, msg = nil)
      msg = message(msg, '') { diff exp, act }
      assert(matches_hash?(exp, act, {exact: true}), msg)
    end
  end
end