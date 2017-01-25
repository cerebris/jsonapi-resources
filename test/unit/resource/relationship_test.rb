require File.expand_path('../../../test_helper', __FILE__)

module Test
  class ImageableResource
  end
end

class HasOneRelationshipTest < ActiveSupport::TestCase

  def test_polymorphic_type
    relationship = JSONAPI::Relationship::ToOne.new("imageable",
      polymorphic: true
    )
    assert_equal(relationship.polymorphic_type, "imageable_type")
  end

  def test_explicit_relationship_class
    relationship = JSONAPI::Relationship::ToOne.new(
      "imageable",
      resource_class: 'Test::ImageableResource'
    )
    assert_equal(Test::ImageableResource, relationship.resource_klass)
  end

end
