require File.expand_path('../../../test_helper', __FILE__)

class UnderscoredKeyFormatterTest < ActiveSupport::TestCase
  def test_undersore_dasherize
    formatted = UnderscoredKeyFormatter.format("Car-Wash")
    assert_equal formatted, "car_wash"
  end
end
