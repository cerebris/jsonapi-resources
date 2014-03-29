require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class SerializerTest < MiniTest::Unit::TestCase
  def setup
    @post = ARPost.first
  end

  def testing_works
    assert(true)
  end
end