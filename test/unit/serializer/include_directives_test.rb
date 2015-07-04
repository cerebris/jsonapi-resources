require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class IncludeDirectivesTest < ActiveSupport::TestCase

  def test_one_level_one_include
    directives = JSONAPI::IncludeDirectives.new(['posts']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related:{}
          }
        }
      },
      directives)
  end

  def test_one_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(['posts', 'comments', 'tags']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related:{}
          },
          comments: {
            include: true,
            include_related:{}
          },
          tags: {
            include: true,
            include_related:{}
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path
    directives = JSONAPI::IncludeDirectives.new(['posts.comments']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related:{
              comments: {
                include: true,
                include_related:{}
              }
            }
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path_redundant
    directives = JSONAPI::IncludeDirectives.new(['posts','posts.comments']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related:{
              comments: {
                include: true,
                include_related:{}
              }
            }
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full
    directives = JSONAPI::IncludeDirectives.new(['posts.comments.tags']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related:{
              comments: {
                include: true,
                include_related:{
                  tags: {
                    include: true,
                    include_related:{}
                  }
                }
              }
            }
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full_model_includes
    directives = JSONAPI::IncludeDirectives.new(['posts.comments.tags'])
    assert_array_equals([{:posts=>[{:comments=>[:tags]}]}], directives.model_includes)
  end
end
