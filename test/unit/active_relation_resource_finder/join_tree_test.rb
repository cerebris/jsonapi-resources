require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class JoinTreeTest < ActiveSupport::TestCase

  def test_no_added_joins
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource)

    assert_hash_equals({root: {alias: 'posts', join_type: :root }, '' => {alias: 'posts', join_type: :root}}, join_tree.joins)
  end

  def test_add_single_join
    filters = {'tags' => ['1']}
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'tags' => {alias: nil, join_type: :inner, relation_join_hash: {'tags' => {}}}
        },
        join_tree.joins)
  end

  def test_add_single_sort_join
    sort_criteria = [ {field: 'tags.name', direction: :desc}]
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, sort_criteria: sort_criteria)
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'tags' => {alias: nil, join_type: :left, relation_join_hash: {'tags' => {}}}
        },
        join_tree.joins)
  end

  def test_add_single_sort_and_filter_join
    filters = {'tags' => ['1']}
    sort_criteria = [ {field: 'tags.name', direction: :desc}]
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, sort_criteria: sort_criteria, filters: filters)
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'tags' => {alias: nil, join_type: :inner, relation_join_hash: {'tags' => {}}}
        },
        join_tree.joins)
  end

  def test_add_sibling_joins
    filters = {
        'tags' => ['1'],
        'author' => ['1']
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)

    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'tags' => {alias: nil, join_type: :inner, relation_join_hash: {'tags' => {}}},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'author' => {}}}
        },
        join_tree.joins)
  end


  def test_add_joins_source_relationship
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    source_relationship: PostResource._relationship(:comments))
    joins = join_tree.joins
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' =>  {alias: nil, join_type: :inner, relation_join_hash: {'comments' => {}}},
        },
        joins)
  end

  def test_add_nested_joins
    filters = {
        'comments.author' => ['1'],
        'comments.tags' => ['1'],
        'author' => ['1']
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)
    joins = join_tree.joins
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'comments' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => {}}},
            'comments.author' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'author' => {}}}},
            'comments.tags' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'tags' => {}}}},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'author' => {}}}
        },
        joins)
  end

  def test_add_nested_joins_with_fields
    filters = {
        'comments.author.name' => ['1'],
        'comments.tags.id' => ['1'],
        'author.foo' => ['1']
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource, filters: filters)

    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'comments' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => {}}},
            'comments.author' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'author' => {}}}},
            'comments.tags' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'tags' => {}}}},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'author' => {}}}
        },
        join_tree.joins)
  end

  def test_add_joins_with_fields_not_from_relationship
    filters = {
        'author.name' => ['1'],
        'author.comments.name' => ['Foo'],
        'tags.id' => ['1']
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    filters: filters)

    joins = join_tree.joins
    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' => {alias: 'posts', join_type: :root},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'author' => {}}},
            'author.comments' => {alias: nil, join_type: :inner, relation_join_hash: { 'author' => { 'comments' => {}}}},
            'tags' => {alias: nil, join_type: :inner, relation_join_hash: {'tags' => {}}},
        },
        joins)
  end

  def test_add_joins_with_fields_from_relationship
    filters = {
        'author.name' => ['1'],
        'author.comments.name' => ['Foo'],
        'tags.id' => ['1']
    }

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    filters: filters,
                                                                    source_relationship: PostResource._relationship(:comments))

    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' =>  {alias: nil, join_type: :inner, relation_join_hash: {'comments' => {}}},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'comments' => { 'author' => {}}}},
            'author.comments' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'author' => { 'comments' => {}}}}},
            'tags' => {alias: nil, join_type: :inner, relation_join_hash: {'comments' => { 'tags' => {}}}}
        },
        join_tree.joins)

    assert join_tree.joins.keys.include?(:root), 'Root must be a symbol'
    refute join_tree.joins.keys.include?('root'), 'Root must be a symbol'
    refute join_tree.joins.keys.include?(:tags), 'Relationship names must be a string'
    assert join_tree.joins.keys.include?('tags'), 'Relationship names must be a string'
  end

  def test_add_joins_with_sub_relationship
    relationships = %w(author author.comments tags)

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    relationships: relationships,
                                                                    source_relationship: PostResource._relationship(:comments))

    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' =>  {alias: nil, join_type: :inner, relation_join_hash: {'comments' => {}}},
            'author' => {alias: nil, join_type: :left, relation_join_hash: {'comments' => { 'author' => {}}}},
            'author.comments' => {alias: nil, join_type: :left, relation_join_hash: { 'comments' => { 'author' => { 'comments' => {}}}}},
            'tags' => {alias: nil, join_type: :left, relation_join_hash: {'comments' => { 'tags' => {}}}}
        },
        join_tree.joins)
  end

  def test_add_joins_with_sub_relationship_and_filters
    filters = {
        'author.name' => ['1'],
        'author.comments.name' => ['Foo']
    }

    relationships = %w(author author.comments tags)

    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PostResource,
                                                                    filters:filters,
                                                                    relationships: relationships,
                                                                    source_relationship: PostResource._relationship(:comments))

    assert_hash_equals(
        {
            root: {alias: 'posts', join_type: :root},
            '' =>  {alias: nil, join_type: :inner, relation_join_hash: {'comments' => {}}},
            'author' => {alias: nil, join_type: :inner, relation_join_hash: {'comments' => { 'author' => {}}}},
            'author.comments' => {alias: nil, join_type: :inner, relation_join_hash: { 'comments' => { 'author' => { 'comments' => {}}}}},
            'tags' => {alias: nil, join_type: :left, relation_join_hash: {'comments' => { 'tags' => {}}}}
        },
        join_tree.joins)
  end

  def test_polymorphic_join_belongs_to_just_source
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource,
                                                                    source_relationship: PictureResource._relationship(:imageable))

    joins = join_tree.joins
    assert_hash_equals(
        {
            root: { alias: 'pictures', join_type: :root},
            '#products' => {alias: nil, join_type: :left, relation_join_hash: {'product' => {}}},
            '#documents' => {alias: nil, join_type: :left, relation_join_hash: {'document' => {}}}
        },
        joins)
  end

  def test_polymorphic_join_belongs_to_filter
    filters = {'imageable' => ['Foo']}
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource, filters: filters)

    joins = join_tree.joins
    assert_hash_equals(
        {
            root: { alias: 'pictures', join_type: :root},
            '' => {alias: 'pictures', join_type: :root},
            'imageable#products' => {alias: nil, join_type: :left, relation_join_hash: {'product' => {}}},
            'imageable#documents' => {alias: nil, join_type: :left, relation_join_hash: {'document' => {}}}
        },
        joins)
  end

  def test_polymorphic_join_belongs_to_filter_on_resource
    filters = {
        'imageable#documents.name' => ['foo']
    }

    relationships = %w(imageable file_properties)
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource,
                                                                    filters: filters,
                                                                    relationships: relationships)
    assert_hash_equals(
        {
            root: { alias: 'pictures', join_type: :root},
            '' => {alias: 'pictures', join_type: :root},
            'imageable#documents' => {alias: nil, join_type: :left, relation_join_hash: {'document' => {}}},
            'imageable#products' => {alias: nil, join_type: :left, relation_join_hash: {'product' => {}}},
            'file_properties' => {alias: nil, join_type: :left, relation_join_hash: {'file_properties' => {}}}
        },
        join_tree.joins)
  end

  def test_polymorphic_join_to_one
    relationships = %w(file_properties)
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource,
                                                                    relationships: relationships)
    assert_hash_equals(
        {
            root: { alias: 'pictures', join_type: :root},
            '' => {alias: 'pictures', join_type: :root},
            'file_properties' => {alias: nil, join_type: :left, relation_join_hash: {'file_properties' => {}}}
        },
        join_tree.joins)
  end

  def test_polymorphic_relationship
    relationships = %w(imageable file_properties)
    join_tree = JSONAPI::ActiveRelationResourceFinder::JoinTree.new(resource_klass: PictureResource,
                                                                    relationships: relationships)
    assert_hash_equals(
        {
            root: { alias: 'pictures', join_type: :root},
            '' => {alias: 'pictures', join_type: :root},
            'imageable#products' => {alias: nil, join_type: :left, relation_join_hash: {'product' => {}}},
            'imageable#documents' => {alias: nil, join_type: :left, relation_join_hash: {'document' => {}}},
            'file_properties' => {alias: nil, join_type: :left, relation_join_hash: {'file_properties' => {}}}
        },
        join_tree.joins)
  end
end
