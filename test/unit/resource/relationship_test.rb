require File.expand_path('../../../test_helper', __FILE__)

class HasOneRelationshipTest < ActiveSupport::TestCase

  def test_polymorphic_type
    relationship = JSONAPI::Relationship::ToOne.new("imageable",
      polymorphic: true
    )
    assert_equal(relationship.polymorphic_type, "imageable_type")
  end

  def test_exclude_links_on_relationship
    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :default
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")
    assert relationship.exclude_link?(:related)
    assert relationship.exclude_link?("related")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: "none"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: "default"
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: [:self]
    assert_equal [:self], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: ["self", :related]
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: []
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    assert_raises do
      JSONAPI::Relationship::ToOne.new "foo", :self
    end
  end
end
