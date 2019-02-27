require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class IncludeDirectivesTest < ActiveSupport::TestCase

  def test_one_level_one_include
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {}
          }
        }
      },
      directives)
  end

  def test_one_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'comments', 'expense_entries']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {}
          },
          comments: {
            include_related: {}
          },
          expense_entries: {
            include_related: {}
          }
        }
      },
      directives)
  end

  def test_multiple_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'posts.comments', 'comments', 'expense_entries']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {
              comments: {
                include_related: {}
              }
            }
          },
          comments: {
            include_related: {}
          },
          expense_entries: {
            include_related: {}
          }
        }
      },
      directives)
  end


  def test_two_levels_include_full_path
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {
              comments: {
                include_related: {}
              }
            }
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path_redundant
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'posts.comments']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {
              comments: {
                include_related: {}
              }
            }
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags']).include_directives

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include_related: {
              comments: {
                include_related: {
                  tags: {
                    include_related: {}
                  }
                }
              }
            }
          }
        }
      },
      directives)
  end

  # def test_three_levels_include_full_model_includes
  #   directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags'])
  #   assert_array_equals([{:posts=>[{:comments=>[:tags]}]}], directives.model_includes)
  # end
  #
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
