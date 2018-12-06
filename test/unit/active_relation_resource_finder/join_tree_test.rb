require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class JoinTreeTest < ActiveSupport::TestCase

  def test_no_added_joins
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource)

    assert_hash_equals({}, join_tree.get_joins)
  end

  def test_add_single_join
    filters = {"tags": ["1"]}
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)
    assert_hash_equals(
        {
            tags: {alias: nil, join_type: :inner, relation_path: {tags: {}}}
        },
        join_tree.get_joins)
  end

  def test_add_single_sort_join
    sort_criteria = [ {field: "tags.name", direction: :desc}]
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, sort_criteria: sort_criteria)
    assert_hash_equals(
        {
            tags: {alias: nil, join_type: :left, relation_path: {tags: {}}}
        },
        join_tree.get_joins)
  end

  def test_add_single_sort_and_filter_join
    filters = {"tags": ["1"]}
    sort_criteria = [ {field: "tags.name", direction: :desc}]
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, sort_criteria: sort_criteria, filters: filters)
    assert_hash_equals(
        {
            tags: {alias: nil, join_type: :inner, relation_path: {tags: {}}}
        },
        join_tree.get_joins)
  end

  def test_add_sibling_joins
    filters = {
        "tags": ["1"],
        "author": ["1"]
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)

    assert_hash_equals(
        {
            tags: {alias: nil, join_type: :inner, relation_path: {tags: {}}},
            author: {alias: nil, join_type: :inner, relation_path: {author: {}}}
        },
        join_tree.get_joins)
  end

  def test_add_nested_joins
    filters = {
        "comments.author": ["1"],
        "comments.tags": ["1"],
        "author": ["1"]
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)
    joins = join_tree.get_joins
    assert_hash_equals(
        {
            "comments": {alias: nil, join_type: :inner, relation_path: {comments: {}}},
            "comments.author": {alias: nil, join_type: :inner, relation_path: {comments: { author: {}}}},
            "comments.tags": {alias: nil, join_type: :inner, relation_path: {comments: { tags: {}}}},
            "author": {alias: nil, join_type: :inner, relation_path: {author: {}}}
        },
        joins)
  end

  def test_add_nested_joins_with_fields
    filters = {
        "comments.author.name": ["1"],
        "comments.tags.id": ["1"],
        "author.foo": ["1"]
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)

    assert_hash_equals(
        {
            "comments": {alias: nil, join_type: :inner, relation_path: {comments: {}}},
            "comments.author": {alias: nil, join_type: :inner, relation_path: {comments: { author: {}}}},
            "comments.tags": {alias: nil, join_type: :inner, relation_path: {comments: { tags: {}}}},
            "author": {alias: nil, join_type: :inner, relation_path: {author: {}}}
        },
        join_tree.get_joins)
  end

  def test_add_joins_with_fields_not_from_relationship
    filters = {
        "author.name": ["1"],
        "author.comments.name": ["Foo"],
        "tags.id": ["1"]
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    filters: filters)

    joins = join_tree.get_joins
    assert_hash_equals(
        {
            "author": {alias: nil, join_type: :inner, relation_path: { author: {}}},
            "author.comments": {alias: nil, join_type: :inner, relation_path: { author: { comments: {}}}},
            "tags": {alias: nil, join_type: :inner, relation_path: { tags: {}}}
        },
        joins)
  end

  def test_add_joins_with_fields_from_relationship
    filters = {
        "author.name": ["1"],
        "author.comments.name": ["Foo"],
        "tags.id": ["1"]
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    filters: filters,
                                                                    source_relationship: PostResource._relationship(:comments))

    assert_hash_equals(
        {
            "author": {alias: nil, join_type: :inner, relation_path: {comments: { author: {}}}},
            "author.comments": {alias: nil, join_type: :inner, relation_path: {comments: { author: { comments: {}}}}},
            "tags": {alias: nil, join_type: :inner, relation_path: {comments: { tags: {}}}}
        },
        join_tree.get_joins)
  end

  def test_polymorphic_join
    filters = {"imageable": ["Foo"]}
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource, filters: filters)
    assert_hash_equals(
        {
            "imageable[product]": {alias: nil, join_type: :left, relation_path: {product: {}}},
            "imageable[document]": {alias: nil, join_type: :left, relation_path: {document: {}}}

        },
        join_tree.get_joins)
  end
end
