require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'
require 'json'

class SerializerTest < ActionDispatch::IntegrationTest
  def setup
    @post = Post.find(1)
    @fred = Person.find_by(name: 'Fred Reader')

    @expense_entry = ExpenseEntry.find(1)

    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :camelized_route
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def after_teardown
    JSONAPI.configuration.always_include_to_one_linkage_data = false
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def test_serializer
    post_1_identity = JSONAPI::ResourceIdentity.new(PostResource, 1)
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['']).include_directives

    id_tree.add_resource_fragment(JSONAPI::ResourceFragment.new(post_1_identity), directives[:include_related])
    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(
        PostResource,
        base_url: 'http://example.com')

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          links: {
            self: 'http://example.com/posts/1',
          },
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          relationships: {
            section: {
              links: {
                self: 'http://example.com/posts/1/relationships/section',
                related: 'http://example.com/posts/1/section'
              }
            },
            author: {
              links: {
                self: 'http://example.com/posts/1/relationships/author',
                related: 'http://example.com/posts/1/author'
              }
            },
            tags: {
              links: {
                self: 'http://example.com/posts/1/relationships/tags',
                related: 'http://example.com/posts/1/tags'
              }
            },
            comments: {
              links: {
                self: 'http://example.com/posts/1/relationships/comments',
                related: 'http://example.com/posts/1/comments'
              }
            }
          }
        }
      },
      serialized
    )
  end

  def test_serializer_nil_handling
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(
        Api::V1::PostResource,
        base_url: 'http://example.com')

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
      {
        data: nil
      },
      serialized
    )
  end

  def test_serializer_namespaced_resource
    post_1_identity = JSONAPI::ResourceIdentity.new(Api::V1::PostResource, 1)
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['']).include_directives

    id_tree.add_resource_fragment(JSONAPI::ResourceFragment.new(post_1_identity), directives[:include_related])
    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(
        Api::V1::PostResource,
        base_url: 'http://example.com')

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          links: {
            self: 'http://example.com/api/v1/posts/1'
          },
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          relationships: {
            section: {
              links:{
                self: 'http://example.com/api/v1/posts/1/relationships/section',
                related: 'http://example.com/api/v1/posts/1/section'
              }
            },
            writer: {
              links:{
                self: 'http://example.com/api/v1/posts/1/relationships/writer',
                related: 'http://example.com/api/v1/posts/1/writer'
              }
            },
            comments: {
              links:{
                self: 'http://example.com/api/v1/posts/1/relationships/comments',
                related: 'http://example.com/api/v1/posts/1/comments'
              }
            }
          }
        }
      },
      serialized
    )
  end

  def test_serializer_limited_fieldset
    post_1_identity = JSONAPI::ResourceIdentity.new(PostResource, 1)
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, []).include_directives

    id_tree.add_resource_fragment(JSONAPI::ResourceFragment.new(post_1_identity), directives[:include_related])
    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(
        PostResource,
        fields: {posts: [:id, :title, :author]})

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
        {
            data: {
                type: 'posts',
                id: '1',
                links: {
                    self: '/posts/1'
                },
                attributes: {
                    title: 'New post'
                },
                relationships: {
                    author: {
                        links: {
                            self: '/posts/1/relationships/author',
                            related: '/posts/1/author'
                        }
                    }
                }
            }
        },
        serialized
    )
  end

  def test_serializer_include
    post_1_identity = JSONAPI::ResourceIdentity.new(PostResource, 1)
    person_1001_identity = JSONAPI::ResourceIdentity.new(PersonResource, 1001)
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['author']).include_directives

    id_tree.add_resource_fragment(JSONAPI::ResourceFragment.new(post_1_identity), directives[:include_related])

    rel_id_tree = id_tree.fetch_related_resource_id_tree(PostResource._relationships[:author])

    author_fragment = JSONAPI::ResourceFragment.new(person_1001_identity)
    author_fragment.add_related_from(post_1_identity)
    author_fragment.add_related_identity(:posts, post_1_identity)
    rel_id_tree.add_resource_fragment(author_fragment, directives[:include_related][:author][:include_related])

    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(PostResource)

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          links: {
            self: '/posts/1'
          },
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          relationships: {
            section: {
              links: {
                self: '/posts/1/relationships/section',
                related: '/posts/1/section'
              }
            },
            author: {
              links: {
                self: '/posts/1/relationships/author',
                related: '/posts/1/author'
              },
              data: {
                type: 'people',
                id: '1001'
              }
            },
            tags: {
              links: {
                self: '/posts/1/relationships/tags',
                related: '/posts/1/tags'
              }
            },
            comments: {
              links: {
                self: '/posts/1/relationships/comments',
                related: '/posts/1/comments'
              }
            }
          }
        },
        included: [
          {
            type: 'people',
            id: '1001',
            attributes: {
              name: 'Joe Author',
              email: 'joe@xyz.fake',
              dateJoined: '2013-08-07 16:25:00 -0400'
            },
            links: {
              self: '/people/1001'
            },
            relationships: {
             comments: {
               links: {
                 self: '/people/1001/relationships/comments',
                 related: '/people/1001/comments'
               }
             },
             posts: {
               links: {
                 self: '/people/1001/relationships/posts',
                 related: '/people/1001/posts'
               },
               data: [
                 {
                   type: 'posts',
                   id: '1'
                 }
               ]
             },
             preferences: {
               links: {
                 self: '/people/1001/relationships/preferences',
                 related: '/people/1001/preferences'
               }
             },
             hairCut: {
               links: {
                 self: '/people/1001/relationships/hairCut',
                 related: '/people/1001/hairCut'
               }
             },
             vehicles: {
               links: {
                 self: '/people/1001/relationships/vehicles',
                 related: '/people/1001/vehicles'
               }
             },
             expenseEntries: {
               links: {
                 self: '/people/1001/relationships/expenseEntries',
                 related: '/people/1001/expenseEntries'
               }
             }
            }
          }
        ]
      },
      serialized
    )
  end

  def test_serializer_key_format
    post_1_identity = JSONAPI::ResourceIdentity.new(PostResource, 1)
    person_1001_identity = JSONAPI::ResourceIdentity.new(PersonResource, 1001)
    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['author']).include_directives

    id_tree.add_resource_fragment(JSONAPI::ResourceFragment.new(post_1_identity), directives[:include_related])

    rel_id_tree = id_tree.fetch_related_resource_id_tree(PostResource._relationships[:author])

    author_fragment = JSONAPI::ResourceFragment.new(person_1001_identity)
    author_fragment.add_related_from(post_1_identity)
    author_fragment.add_related_identity(:posts, post_1_identity)
    rel_id_tree.add_resource_fragment(author_fragment, directives[:include_related][:author][:include_related])

    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(PostResource,
                                                 key_formatter: UnderscoredKeyFormatter,)

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
        {
            data: {
                type: 'posts',
                id: '1',
                links: {
                    self: '/posts/1'
                },
                attributes: {
                    title: 'New post',
                    body: 'A body!!!',
                    subject: 'New post'
                },
                relationships: {
                    section: {
                        links: {
                            self: '/posts/1/relationships/section',
                            related: '/posts/1/section'
                        }
                    },
                    author: {
                        links: {
                            self: '/posts/1/relationships/author',
                            related: '/posts/1/author'
                        },
                        data: {
                            type: 'people',
                            id: '1001'
                        }
                    },
                    tags: {
                        links: {
                            self: '/posts/1/relationships/tags',
                            related: '/posts/1/tags'
                        }
                    },
                    comments: {
                        links: {
                            self: '/posts/1/relationships/comments',
                            related: '/posts/1/comments'
                        }
                    }
                }
            },
            included: [
                {
                    type: 'people',
                    id: '1001',
                    attributes: {
                        name: 'Joe Author',
                        email: 'joe@xyz.fake',
                        date_joined: '2013-08-07 16:25:00 -0400'
                    },
                    links: {
                        self: '/people/1001'
                    },
                    relationships: {
                        comments: {
                            links: {
                                self: '/people/1001/relationships/comments',
                                related: '/people/1001/comments'
                            }
                        },
                        posts: {
                            links: {
                                self: '/people/1001/relationships/posts',
                                related: '/people/1001/posts'
                            },
                            data: [
                                {
                                    type: 'posts',
                                    id: '1'
                                }
                            ]
                        },
                        preferences: {
                            links: {
                                self: '/people/1001/relationships/preferences',
                                related: '/people/1001/preferences'
                            }
                        },
                        hair_cut: {
                            links: {
                                self: '/people/1001/relationships/hairCut',
                                related: '/people/1001/hairCut'
                            }
                        },
                        vehicles: {
                            links: {
                                self: '/people/1001/relationships/vehicles',
                                related: '/people/1001/vehicles'
                            }
                        },
                        expense_entries: {
                            links: {
                                self: '/people/1001/relationships/expenseEntries',
                                related: '/people/1001/expenseEntries'
                            }
                        }
                    }
                }
            ]
        },
        serialized
    )
  end

  def test_serializers_linkage_even_without_included_resource

    post_1_identity = JSONAPI::ResourceIdentity.new(PostResource, 1)
    person_1001_identity = JSONAPI::ResourceIdentity.new(PersonResource, 1001)

    id_tree = JSONAPI::PrimaryResourceIdTree.new

    directives = JSONAPI::IncludeDirectives.new(PersonResource, []).include_directives

    fragment = JSONAPI::ResourceFragment.new(post_1_identity)

    fragment.add_related_identity(:author, person_1001_identity)
    fragment.initialize_related(:section)
    fragment.initialize_related(:tags)

    id_tree.add_resource_fragment(fragment, directives[:include_related])
    resource_set = JSONAPI::ResourceSet.new(id_tree)

    serializer = JSONAPI::ResourceSerializer.new(PostResource)

    resource_set.populate!(serializer, {}, {})
    serialized = serializer.serialize_resource_set_to_hash_single(resource_set)

    assert_hash_equals(
      {
        data:
          {
            id: '1',
            type: 'posts',
            links: {
                self: '/posts/1'
            },
            attributes: {
              title: 'New post',
              body: 'A body!!!',
              subject: 'New post'
            },
            relationships: {
              author: {
                  links: {
                      self: '/posts/1/relationships/author',
                      related: '/posts/1/author'
                  },
                  data: {
                      type: 'people',
                      id: '1001'
                  }
              },
              section: {
                links: {
                  self: '/posts/1/relationships/section',
                  related: '/posts/1/section'
                },
                data: nil
              },
              tags: {
                links: {
                  self: '/posts/1/relationships/tags',
                  related: '/posts/1/tags'
                },
                data: []
              },
              comments: {
                links: {
                  self: '/posts/1/relationships/comments',
                  related: '/posts/1/comments'
                }
              }
            }
          }
      },
      serialized
    )
  end
end
