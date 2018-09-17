require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class IncludeDirectivesTest < ActiveSupport::TestCase

  def test_one_level_one_include
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related: {},
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_no_includes_always_include_linkage
    JSONAPI.configuration.always_include_to_one_linkage_data = true

    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['']).include_directives

    assert_hash_equals(
        {
            include_related: {},
            include_linkage: {
                preferences: {},
                hair_cut: {}
            }
        },
        directives)
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_one_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'comments', 'tags']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related: {},
            include_in_join: true
          },
          comments: {
            include: true,
            include_linkage: {},
            include_related: {},
            include_in_join: true
          },
          tags: {
            include: true,
            include_linkage: {},
            include_related: {},
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related:{
              comments: {
                include: true,
                include_linkage: {},
                include_related: {},
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_no_eager_join
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.tags']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related:{
              tags: {
                include: true,
                include_linkage: {},
                include_related: {},
                include_in_join: false
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path_redundant
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts','posts.comments']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related:{
              comments: {
                include: true,
                include_linkage: {},
                include_related: {},
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags']).include_directives

    assert_hash_equals(
      {
        include_linkage: {},
        include_related: {
          posts: {
            include: true,
            include_linkage: {},
            include_related:{
              comments: {
                include: true,
                include_linkage: {},
                include_related:{
                  tags: {
                    include: true,
                    include_linkage: {},
                    include_related: {},
                    include_in_join: true
                  }
                },
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full_model_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags'])
    assert_array_equals([{:posts=>[{:comments=>[:tags]}]}], directives.model_includes)
  end

  def test_invalid_includes_1
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['../../../../']).include_directives
    end
  end

  def test_invalid_includes_2
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['posts./sdaa./........']).include_directives
    end
  end

  def test_invalid_includes_3
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['invalid../../../../']).include_directives
    end
  end
end
