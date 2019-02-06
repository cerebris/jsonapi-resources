require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class PathTest < ActiveSupport::TestCase

  def test_one_relationship
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments')

    assert path.parts.is_a?(Array)
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert_equal Api::V1::PostResource._relationship(:comments), path.parts[0].relationship
  end

  def test_one_field
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'title')

    assert path.parts.is_a?(Array)
    assert path.parts[0].is_a?(JSONAPI::PathPart::Field), "should be a PathPart::Field"
    assert_equal 'title', path.parts[0].field_name
  end

  def test_two_relationships
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author')

    assert path.parts.is_a?(Array)
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert path.parts[1].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert_equal Api::V1::PostResource._relationship(:comments), path.parts[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.parts[1].relationship
  end

  def test_two_relationships_and_field
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author.name')

    assert path.parts.is_a?(Array)
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert path.parts[1].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert path.parts[2].is_a?(JSONAPI::PathPart::Field), "should be a PathPart::Field"

    assert_equal Api::V1::PostResource._relationship(:comments), path.parts[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.parts[1].relationship
    assert_equal 'name', path.parts[2].field_name
  end

  def test_two_relationships_and_parse_fields_false_raises_with_field

    assert_raises JSONAPI::Exceptions::InvalidRelationship do
      path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource,
                               path_string: 'comments.author.name',
                               parse_fields: false)
    end
  end

  def test_ensure_default_field_false
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author', ensure_default_field: false)

    assert path.parts.is_a?(Array)
    assert_equal 2, path.parts.length
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert path.parts[1].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"

    assert_equal Api::V1::PostResource._relationship(:comments), path.parts[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.parts[1].relationship
  end

  def test_ensure_default_field_true
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author', ensure_default_field: true)

    assert path.parts.is_a?(Array)
    assert_equal 3, path.parts.length
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert path.parts[1].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"

    assert_equal Api::V1::PostResource._relationship(:comments), path.parts[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.parts[1].relationship
  end

  def test_polymorphic_path
    path = JSONAPI::Path.new(resource_klass: PictureResource, path_string: :imageable)

    assert path.parts.is_a?(Array)
    assert path.parts[0].is_a?(JSONAPI::PathPart::Relationship), "should be a PathPart::Relationship"
    assert_equal PictureResource._relationship(:imageable), path.parts[0].relationship
  end
end
