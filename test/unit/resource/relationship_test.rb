require File.expand_path('../../../test_helper', __FILE__)

class HasOneRelationshipTest < ActiveSupport::TestCase

  def test_polymorphic_type
    relationship = JSONAPI::Relationship::ToOne.new("imageable",
      polymorphic: true
    )
    assert_equal(relationship.polymorphic_type, "imageable_type")
  end

end
