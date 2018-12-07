require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'
require 'json'

class DefaultProcessorTest < ActionDispatch::IntegrationTest
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :camelized_route
    JSONAPI.configuration.always_include_to_one_linkage_data = false

    JSONAPI.configuration.resource_cache = ActiveSupport::Cache::MemoryStore.new
    PostResource.caching true
    PersonResource.caching true

    $serializer = JSONAPI::ResourceSerializer.new(PostResource, base_url: 'http://example.com')

    # no includes
    filters = { id: [10, 12] }

    find_options = { filters: filters }
    params = {
        filters: filters,
        include_directives: {},
        sort_criteria: {},
        paginator: {},
        fields: {},
        serializer: {}
    }
    p = JSONAPI::Processor.new(PostResource, :find, params)
    $id_tree_no_includes = p.send(:find_resource_id_tree, PostResource, find_options, {})
    $resource_set_no_includes = JSONAPI::ResourceSet.new($id_tree_no_includes)
    $populated_resource_set_no_includes = JSONAPI::ResourceSet.new($id_tree_no_includes).populate!($serializer, nil,{})

    # has_one included
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['author']).include_directives
    params = {
        filters: filters,
        include_directives: directives,
        sort_criteria: {},
        paginator: {},
        fields: {},
        serializer: {}
    }
    p = JSONAPI::Processor.new(PostResource, :find, params)

    $id_tree_has_one_includes = p.send(:find_resource_id_tree, PostResource, find_options, directives)
    $resource_set_has_one_includes = JSONAPI::ResourceSet.new($id_tree_has_one_includes)
    $populated_resource_set_has_one_includes = JSONAPI::ResourceSet.new($id_tree_has_one_includes).populate!($serializer, nil,{})
  end

  def after_teardown
    JSONAPI.configuration.always_include_to_one_linkage_data = false
    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :underscored_route

    JSONAPI.configuration.resource_cache = nil
    PostResource.caching nil
    PersonResource.caching nil
  end

  def test_id_tree_without_includes_should_be_a_resource_id_tree
    assert $id_tree_no_includes.is_a?(JSONAPI::PrimaryResourceIdTree)
  end

  def test_id_tree_without_includes_should_have_resources
    assert_equal 2, $id_tree_no_includes.fragments.size
  end

  def test_id_tree_without_includes_should_not_have_related_resources
    assert_empty $id_tree_no_includes.related_resource_id_trees
  end

  def test_id_tree_without_includes_resource_relationships_should_be_empty
    assert_equal 0, $id_tree_no_includes.fragments[JSONAPI::ResourceIdentity.new(PostResource, 10)].related.length
    assert_equal 0, $id_tree_no_includes.fragments[JSONAPI::ResourceIdentity.new(PostResource, 12)].related.length
  end

  def test_id_tree_has_one_includes_should_be_a_resource_id_tree
    assert $id_tree_has_one_includes.is_a?(JSONAPI::PrimaryResourceIdTree)
  end

  def test_id_tree_has_one_includes_should_have_included_resources
    assert $id_tree_has_one_includes.related_resource_id_trees.is_a?(Hash)
    assert $id_tree_has_one_includes.related_resource_id_trees[:author].is_a?(JSONAPI::RelatedResourceIdTree)
    assert_equal 2, $id_tree_has_one_includes.related_resource_id_trees[:author].fragments.size
  end

  def test_id_tree_has_one_includes_should_have_resources
    assert_equal 2, $id_tree_has_one_includes.fragments.size
  end

  def test_id_tree_has_one_includes_resource_relationships_should_have_rids
    assert_equal 1, $id_tree_has_one_includes.fragments[JSONAPI::ResourceIdentity.new(PostResource, 10)].related[:author].length
    assert_equal 1, $id_tree_has_one_includes.fragments[JSONAPI::ResourceIdentity.new(PostResource, 12)].related[:author].length
  end

  def test_populated_resource_set_has_one_includes_have_resources
    assert $populated_resource_set_has_one_includes.resource_klasses[PostResource][10].is_a?(Hash)
    assert $populated_resource_set_has_one_includes.resource_klasses[PostResource][12].is_a?(Hash)
    assert $populated_resource_set_has_one_includes.resource_klasses[PersonResource][1003].is_a?(Hash)
    assert $populated_resource_set_has_one_includes.resource_klasses[PersonResource][1004].is_a?(Hash)
  end

  def test_populated_resource_set_has_one_includes_relationships_are_resolved
    assert_equal 1003, $populated_resource_set_has_one_includes.resource_klasses[PostResource][10][:relationships][:author].first.id
    assert_equal 1004, $populated_resource_set_has_one_includes.resource_klasses[PostResource][12][:relationships][:author].first.id
  end

end