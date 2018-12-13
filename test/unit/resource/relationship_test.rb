require File.expand_path('../../../test_helper', __FILE__)

class LambdaBlogPostsResource < JSONAPI::Resource
  model_name 'Post'

  has_one :author, allow_include: -> (context) { context[:admin] }
  has_many :comments, allow_include: -> (context) { context[:admin] }
end

class CallableBlogPostsResource < JSONAPI::Resource
  model_name 'Post'

  has_one :author, allow_include: :is_admin
  has_many :comments, allow_include: :is_admin

  def self.is_admin(context)
    context[:admin]
  end
end

class HasOneRelationshipTest < ActiveSupport::TestCase

  def test_polymorphic_type
    relationship = JSONAPI::Relationship::ToOne.new("imageable",
      polymorphic: true
    )
    assert_equal(relationship.polymorphic_type, "imageable_type")
  end

  def test_allow_include_not_set_defaults_to_config_to_one
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship = JSONAPI::Relationship::ToOne.new("foo")
    assert(relationship.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    relationship = JSONAPI::Relationship::ToOne.new("foo")
    refute(relationship.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_not_set_defaults_to_config_to_many
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_many = true
    relationship = JSONAPI::Relationship::ToMany.new("foobar")
    assert(relationship.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    relationship = JSONAPI::Relationship::ToOne.new("foobar")
    refute(relationship.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_overrides_to_config_to_one
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship1 = JSONAPI::Relationship::ToOne.new("foo1", allow_include: false)
    relationship2 = JSONAPI::Relationship::ToOne.new("foo2", allow_include: true)
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_overrides_to_config_to_many
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship1 = JSONAPI::Relationship::ToMany.new("foobar1", allow_include: false)
    relationship2 = JSONAPI::Relationship::ToMany.new("foobar2", allow_include: true)
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_by_lambda
    assert LambdaBlogPostsResource._relationship(:author).allow_include?(admin: true)
    refute LambdaBlogPostsResource._relationship(:author).allow_include?(admin: false)

    assert LambdaBlogPostsResource._relationship(:comments).allow_include?(admin: true)
    refute LambdaBlogPostsResource._relationship(:comments).allow_include?(admin: false)
  end

  def test_allow_include_set_by_callable
    assert CallableBlogPostsResource._relationship(:author).allow_include?(admin: true)
    refute CallableBlogPostsResource._relationship(:author).allow_include?(admin: false)

    assert CallableBlogPostsResource._relationship(:comments).allow_include?(admin: true)
    refute CallableBlogPostsResource._relationship(:comments).allow_include?(admin: false)
  end

end
