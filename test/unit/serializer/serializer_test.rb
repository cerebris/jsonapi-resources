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
  end

  def after_teardown
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def test_serializer

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: 'http://example.com/posts/1',
            section: {
              self: 'http://example.com/posts/1/links/section',
              related: 'http://example.com/posts/1/section',
              linkage: nil
            },
            author: {
              self: 'http://example.com/posts/1/links/author',
              related: 'http://example.com/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: 'http://example.com/posts/1/links/tags',
              related: 'http://example.com/posts/1/tags'
            },
            comments: {
              self: 'http://example.com/posts/1/links/comments',
              related: 'http://example.com/posts/1/comments'
            }
          }
        },
        links: {
          self: 'http://example.com/posts/1'
        }
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      base_url: 'http://example.com').serialize_to_hash(PostResource.new(@post))
    )
  end

  def test_serializer_nil_handling
    assert_hash_equals(
      {
        data: nil,
        links: {
          self: '/posts'
        }
      },
      JSONAPI::ResourceSerializer.new(PostResource).serialize_to_hash(nil)
    )
  end

  def test_serializer_namespaced_resource
    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: 'http://example.com/api/v1/posts/1',
            section: {
              self: 'http://example.com/api/v1/posts/1/links/section',
              related: 'http://example.com/api/v1/posts/1/section',
              linkage: nil
            },
            writer: {
              self: 'http://example.com/api/v1/posts/1/links/writer',
              related: 'http://example.com/api/v1/posts/1/writer',
              linkage: {
                type: 'writers',
                id: '1'
              }
            },
            comments: {
              self: 'http://example.com/api/v1/posts/1/links/comments',
              related: 'http://example.com/api/v1/posts/1/comments'
            }
          }
        },
        links: {
          self: 'http://example.com/api/v1/posts/1'
        }
      },
      JSONAPI::ResourceSerializer.new(Api::V1::PostResource,
                                      base_url: 'http://example.com').serialize_to_hash(
        Api::V1::PostResource.new(@post))
    )
  end

  def test_serializer_limited_fieldset

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post'
          },
          links: {
            self: '/posts/1',
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            }
          }
        },
        links: {
          self: '/posts/1'
        }
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      fields: {posts: [:id, :title, :author]}).serialize_to_hash(PostResource.new(@post))
    )
  end

  def test_serializer_include
    serialized = JSONAPI::ResourceSerializer.new(
      PostResource,
      include: ['author']
    ).serialize_to_hash(PostResource.new(@post))

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: '/posts/1',
            section: {
              self: '/posts/1/links/section',
              related: '/posts/1/section',
              linkage: nil
            },
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: '/posts/1/links/tags',
              related: '/posts/1/tags'
            },
            comments: {
              self: '/posts/1/links/comments',
              related: '/posts/1/comments'
            }
          }
        },
        links: {
          self: '/posts/1'
        },
        included: [
          {
            type: 'people',
            id: '1',
            attributes: {
              name: 'Joe Author',
              email: 'joe@xyz.fake',
              dateJoined: '2013-08-07 16:25:00 -0400'
            },
            links: {
             self: '/people/1',
             comments: {
               self: '/people/1/links/comments',
               related: '/people/1/comments'
             },
             posts: {
               self: '/people/1/links/posts',
               related: '/people/1/posts'
             },
             preferences: {
               self: '/people/1/links/preferences',
               related: '/people/1/preferences',
               linkage: {
                 type: 'preferences',
                 id: '1'
               }
             },
             hairCut: {
               self: "/people/1/links/hairCut",
               related: "/people/1/hairCut",
               linkage: nil
             }
            }
          }
        ]
      },
      serialized
    )
  end

  def test_serializer_key_format
    serialized = JSONAPI::ResourceSerializer.new(
      PostResource,
      include: ['author'],
      key_formatter: UnderscoredKeyFormatter
    ).serialize_to_hash(PostResource.new(@post))

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: '/posts/1',
            section: {
              self: '/posts/1/links/section',
              related: '/posts/1/section',
              linkage: nil
            },
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: '/posts/1/links/tags',
              related: '/posts/1/tags'
            },
            comments: {
              self: '/posts/1/links/comments',
              related: '/posts/1/comments'
            }
          }
        },
        links: {
          self: '/posts/1'
        },
        included: [
          {
            type: 'people',
            id: '1',
            attributes: {
              name: 'Joe Author',
              email: 'joe@xyz.fake',
              date_joined: '2013-08-07 16:25:00 -0400'
            },
            links: {
              self: '/people/1',
              comments: {
                self: '/people/1/links/comments',
                related: '/people/1/comments'
              },
              posts: {
                self: '/people/1/links/posts',
                related: '/people/1/posts'
              },
              preferences: {
                self: '/people/1/links/preferences',
                related: '/people/1/preferences',
                linkage: {
                  type: 'preferences',
                  id: '1'
                }
              },
              hair_cut: {
                self: '/people/1/links/hairCut',
                related: '/people/1/hairCut',
                linkage: nil
              }
            }
          }
        ]
      },
      serialized
    )
  end

  def test_serializer_include_sub_objects

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: '/posts/1',
            section: {
              self: '/posts/1/links/section',
              related: '/posts/1/section',
              linkage: nil
            },
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: '/posts/1/links/tags',
              related: '/posts/1/tags'
            },
            comments: {
              self: '/posts/1/links/comments',
              related: '/posts/1/comments',
              linkage: [
                {type: 'comments', id: '1'},
                {type: 'comments', id: '2'}
              ]
            }
          }
        },
        links: {
          self: '/posts/1'
        },
        included: [
            {
              type: 'tags',
              id: '1',
              attributes: {
                name: 'short'
              },
              links: {
                self: '/tags/1',
                posts: {
                  self: '/tags/1/links/posts',
                  related: '/tags/1/posts'
                }
              }
            },
            {
              type: 'tags',
              id: '2',
              attributes: {
                name: 'whiny'
              },
              links: {
                self: '/tags/2',
                posts: {
                  self: '/tags/2/links/posts',
                  related: '/tags/2/posts'
                }
              }
            },
            {
              type: 'tags',
              id: '4',
              attributes: {
                name: 'happy'
              },
              links: {
                self: '/tags/4',
                posts: {
                  self: '/tags/4/links/posts',
                  related: '/tags/4/posts',
                }
              }
            },
            {
              type: 'comments',
              id: '1',
              attributes: {
                body: 'what a dumb post'
              },
              links: {
                self: '/comments/1',
                author: {
                  self: '/comments/1/links/author',
                  related: '/comments/1/author',
                  linkage: {
                    type: 'people',
                    id: '1'
                  }
                },
                post: {
                  self: '/comments/1/links/post',
                  related: '/comments/1/post',
                  linkage: {
                    type: 'posts',
                    id: '1'
                  }
                },
                tags: {
                  self: '/comments/1/links/tags',
                  related: '/comments/1/tags',
                  linkage: [
                    {type: 'tags', id: '1'},
                    {type: 'tags', id: '2'}
                  ]
                }
              }
            },
            {
              type: 'comments',
              id: '2',
              attributes: {
                body: 'i liked it'
              },
              links: {
                self: '/comments/2',
                author: {
                  self: '/comments/2/links/author',
                  related: '/comments/2/author',
                  linkage: {
                    type: 'people',
                    id: '2'
                  }
                },
                post: {
                  self: '/comments/2/links/post',
                  related: '/comments/2/post',
                  linkage: {
                    type: 'posts',
                    id: '1'
                  }
                },
                tags: {
                  self: '/comments/2/links/tags',
                  related: '/comments/2/tags',
                  linkage: [
                    {type: 'tags', id: '1'},
                    {type: 'tags', id: '4'}
                  ]
                }
              }
            }
          ]
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      include: ['comments', 'comments.tags']).serialize_to_hash(PostResource.new(@post))
    )
  end

  def test_serializer_include_has_many_sub_objects_only

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: '/posts/1',
            section: {
              self: '/posts/1/links/section',
              related: '/posts/1/section',
              linkage: nil
            },
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: '/posts/1/links/tags',
              related: '/posts/1/tags'
            },
            comments: {
              self: '/posts/1/links/comments',
              related: '/posts/1/comments'
            }
          }
        },
        links: {
          self: '/posts/1'
        },
        included: [
          {
            type: 'tags',
            id: '1',
            attributes: {
              name: 'short'
            },
            links: {
              self: '/tags/1',
              posts: {
                self: '/tags/1/links/posts',
                related: '/tags/1/posts'
              }
            }
          },
          {
            type: 'tags',
            id: '2',
            attributes: {
              name: 'whiny'
            },
            links: {
              self: '/tags/2',
              posts: {
                self: '/tags/2/links/posts',
                related: '/tags/2/posts'
              }
            }
          },
          {
            type: 'tags',
            id: '4',
            attributes: {
              name: 'happy'
            },
            links: {
              self: '/tags/4',
              posts: {
                self: '/tags/4/links/posts',
                related: '/tags/4/posts',
              }
            }
          }
        ]
      },
      JSONAPI::ResourceSerializer.new(PostResource, include: ['comments.tags']).serialize_to_hash(PostResource.new(@post))
    )
  end

  def test_serializer_include_has_one_sub_objects_only

    assert_hash_equals(
      {
        data: {
          type: 'posts',
          id: '1',
          attributes: {
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post'
          },
          links: {
            self: '/posts/1',
            section: {
              self: '/posts/1/links/section',
              related: '/posts/1/section',
              linkage: nil
            },
            author: {
              self: '/posts/1/links/author',
              related: '/posts/1/author',
              linkage: {
                type: 'people',
                id: '1'
              }
            },
            tags: {
              self: '/posts/1/links/tags',
              related: '/posts/1/tags'
            },
            comments: {
              self: '/posts/1/links/comments',
              related: '/posts/1/comments'
            }
          }
        },
        links: {
          self: '/posts/1'
        },
        included: [
          {
            type: 'comments',
            id: '1',
            attributes: {
              body: 'what a dumb post'
            },
            links: {
              self: '/comments/1',
              author: {
                self: '/comments/1/links/author',
                related: '/comments/1/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              },
              post: {
                self: '/comments/1/links/post',
                related: '/comments/1/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                self: '/comments/1/links/tags',
                related: '/comments/1/tags'
              }
            }
          }
        ]
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      include: ['author.comments']).serialize_to_hash(PostResource.new(@post))
    )
  end

  def test_serializer_different_foreign_key
    serialized = JSONAPI::ResourceSerializer.new(
      PersonResource,
      include: ['comments']
    ).serialize_to_hash(PersonResource.new(@fred))

    assert_hash_equals(
      {
        data: {
          type: 'people',
          id: '2',
          attributes: {
            name: 'Fred Reader',
            email: 'fred@xyz.fake',
            dateJoined: '2013-10-31 16:25:00 -0400'
          },
          links: {
            self: '/people/2',
            posts: {
              self: '/people/2/links/posts',
              related: '/people/2/posts'
            },
            comments: {
              self: '/people/2/links/comments',
              related: '/people/2/comments',
              linkage: [
                {type: 'comments', id: '2'},
                {type: 'comments', id: '3'}
              ]
            },
            preferences: {
              self: "/people/2/links/preferences",
              related: "/people/2/preferences",
              linkage: nil
            },
            hairCut: {
              self: "/people/2/links/hairCut",
              related: "/people/2/hairCut",
              linkage: nil
            }
          }
        },
        links: {
          self: '/people/2'
        },
        included: [
          {
            type: 'comments',
            id: '2',
            attributes: {
              body: 'i liked it'
            },
            links: {
              self: '/comments/2',
              author: {
                self: '/comments/2/links/author',
                related: '/comments/2/author',
                linkage: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                self: '/comments/2/links/post',
                related: '/comments/2/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                self: '/comments/2/links/tags',
                related: '/comments/2/tags'
              }
            }
          },
          {
            type: 'comments',
            id: '3',
            attributes: {
              body: 'Thanks man. Great post. But what is JR?'
            },
            links: {
              self: '/comments/3',
              author: {
                self: '/comments/3/links/author',
                related: '/comments/3/author',
                linkage: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                self: '/comments/3/links/post',
                related: '/comments/3/post',
                linkage: {
                  type: 'posts',
                  id: '2'
                }
              },
              tags: {
                self: '/comments/3/links/tags',
                related: '/comments/3/tags'
              }
            }
          }
        ]
      },
      serialized
    )
  end

  def test_serializer_array_of_resources

    posts = []
    Post.find(1, 2).each do |post|
      posts.push PostResource.new(post)
    end

    assert_hash_equals(
      {
        data: [
          {
            type: 'posts',
            id: '1',
            attributes: {
              title: 'New post',
              body: 'A body!!!',
              subject: 'New post'
            },
            links: {
              self: '/posts/1',
              section: {
                self: '/posts/1/links/section',
                related: '/posts/1/section',
                linkage: nil
              },
              author: {
                self: '/posts/1/links/author',
                related: '/posts/1/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              },
              tags: {
                self: '/posts/1/links/tags',
                related: '/posts/1/tags'
              },
              comments: {
                self: '/posts/1/links/comments',
                related: '/posts/1/comments',
                linkage: [
                  {type: 'comments', id: '1'},
                  {type: 'comments', id: '2'}
                ]
              }
            }
          },
          {
            type: 'posts',
            id: '2',
            attributes: {
              title: 'JR Solves your serialization woes!',
              body: 'Use JR',
              subject: 'JR Solves your serialization woes!'
            },
            links: {
              self: '/posts/2',
              section: {
                self: '/posts/2/links/section',
                related: '/posts/2/section',
                linkage: {
                  type: 'sections',
                  id: '2'
                }
              },
              author: {
                self: '/posts/2/links/author',
                related: '/posts/2/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              },
              tags: {
                self: '/posts/2/links/tags',
                related: '/posts/2/tags'
              },
              comments: {
                self: '/posts/2/links/comments',
                related: '/posts/2/comments',
                linkage: [
                  {type: 'comments', id: '3'}
                ]
              }
            }
          }
        ],
        links: {
          self: '/posts'
        },
        included: [
          {
            type: 'tags',
            id: '1',
            attributes: {
              name: 'short'
            },
            links: {
              self: '/tags/1',
              posts: {
                self: '/tags/1/links/posts',
                related: '/tags/1/posts'
              }
            }
          },
          {
            type: 'tags',
            id: '2',
            attributes: {
              name: 'whiny'
            },
            links: {
              self: '/tags/2',
              posts: {
                self: '/tags/2/links/posts',
                related: '/tags/2/posts'
              }
            }
          },
          {
            type: 'tags',
            id: '4',
            attributes: {
              name: 'happy'
            },
            links: {
              self: '/tags/4',
              posts: {
                self: '/tags/4/links/posts',
                related: '/tags/4/posts',
              }
            }
          },
          {
            type: 'tags',
            id: '5',
            attributes: {
              name: 'JR'
            },
            links: {
              self: '/tags/5',
              posts: {
                self: '/tags/5/links/posts',
                related: '/tags/5/posts',
              }
            }
          },
          {
            type: 'comments',
            id: '1',
            attributes: {
              body: 'what a dumb post'
            },
            links: {
              self: '/comments/1',
              author: {
                self: '/comments/1/links/author',
                related: '/comments/1/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              },
              post: {
                self: '/comments/1/links/post',
                related: '/comments/1/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                self: '/comments/1/links/tags',
                related: '/comments/1/tags',
                linkage: [
                  {type: 'tags', id: '1'},
                  {type: 'tags', id: '2'}
                ]
              }
            }
          },
          {
            type: 'comments',
            id: '2',
            attributes: {
              body: 'i liked it'
            },
            links: {
              self: '/comments/2',
              author: {
                self: '/comments/2/links/author',
                related: '/comments/2/author',
                linkage: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                self: '/comments/2/links/post',
                related: '/comments/2/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                self: '/comments/2/links/tags',
                related: '/comments/2/tags',
                linkage: [
                  {type: 'tags', id: '4'},
                  {type: 'tags', id: '1'}
                ]
              }
            }
          },
          {
            type: 'comments',
            id: '3',
            attributes: {
              body: 'Thanks man. Great post. But what is JR?'
            },
            links: {
              self: '/comments/3',
              author: {
                self: '/comments/3/links/author',
                related: '/comments/3/author',
                linkage: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                self: '/comments/3/links/post',
                related: '/comments/3/post',
                linkage: {
                  type: 'posts',
                  id: '2'
                }
              },
              tags: {
                self: '/comments/3/links/tags',
                related: '/comments/3/tags',
                linkage: [
                  {type: 'tags', id: '5'}
                ]
              }
            }
          }
        ]
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      include: ['comments', 'comments.tags']).serialize_to_hash(posts)
    )
  end

  def test_serializer_array_of_resources_limited_fields

    posts = []
    Post.find(1, 2).each do |post|
      posts.push PostResource.new(post)
    end

    assert_hash_equals(
      {
        data: [
          {
            type: 'posts',
            id: '1',
            attributes: {
              title: 'New post'
            },
            links: {
              self: '/posts/1',
              author: {
                self: '/posts/1/links/author',
                related: '/posts/1/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              }
            }
          },
          {
            type: 'posts',
            id: '2',
            attributes: {
              title: 'JR Solves your serialization woes!'
            },
            links: {
              self: '/posts/2',
              author: {
                self: '/posts/2/links/author',
                related: '/posts/2/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              }
            }
          }
        ],
        links: {
          self: '/posts'
        },
        included: [
          {
            type: 'posts',
            id: '11',
            attributes: {
              title: 'JR How To'
            },
            links: {
              self: '/posts/11',
              author: {
                self: '/posts/11/links/author',
                related: '/posts/11/author',
                linkage: {
                  type: 'people',
                  id: '1'
                }
              }
            }
          },
          {
            type: 'people',
            id: '1',
            attributes: {
              email: 'joe@xyz.fake'
            },
            links: {
              self: '/people/1',
              comments: {
                self: '/people/1/links/comments',
                related: '/people/1/comments'
              }
            }
          },
          {
            id: '1',
            type: 'tags',
            attributes: {
              name: 'short'
            },
            links: {
              self: '/tags/1'
            }
          },
          {
            id: '2',
            type: 'tags',
            attributes: {
              name: 'whiny'
            },
            links: {
              self: '/tags/2'
            }
          },
          {
            id: '4',
            type: 'tags',
            attributes: {
              name: 'happy'
            },
            links: {
              self: '/tags/4'
            }
          },
          {
            id: '5',
            type: 'tags',
            attributes: {
              name: 'JR'
            },
            links: {
              self: '/tags/5'
            }
          },
          {
            type: 'comments',
            id: '1',
            attributes: {
              body: 'what a dumb post'
            },
            links: {
              self: '/comments/1',
              post: {
                self: '/comments/1/links/post',
                related: '/comments/1/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              }
            }
          },
          {
            type: 'comments',
            id: '2',
            attributes: {
              body: 'i liked it'
            },
            links: {
              self: '/comments/2',
              post: {
                self: '/comments/2/links/post',
                related: '/comments/2/post',
                linkage: {
                  type: 'posts',
                  id: '1'
                }
              }
            }
          },
          {
            type: 'comments',
            id: '3',
            attributes: {
              body: 'Thanks man. Great post. But what is JR?'
            },
            links: {
              self: '/comments/3',
              post: {
                self: '/comments/3/links/post',
                related: '/comments/3/post',
                linkage: {
                  type: 'posts',
                  id: '2'
                }
              }
            }
          }
        ]
      },
      JSONAPI::ResourceSerializer.new(PostResource,
                                      include: ['comments', 'author', 'comments.tags', 'author.posts'],
                                      fields: {
                                        people: [:id, :email, :comments],
                                        posts: [:id, :title, :author],
                                        tags: [:name],
                                        comments: [:id, :body, :post]
                                      }).serialize_to_hash(posts)
    )
  end

  def test_serializer_camelized_with_value_formatters
    # JSONAPI.configuration.json_key_format = :camelized_key
    # JSONAPI.configuration.route_format = :camelized_route

    assert_hash_equals(
      {
        data: {
          type: 'expenseEntries',
          id: '1',
          attributes: {
            transactionDate: '04/15/2014',
            cost: 12.05
          },
          links: {
            self: '/expenseEntries/1',
            isoCurrency: {
              self: '/expenseEntries/1/links/isoCurrency',
              related: '/expenseEntries/1/isoCurrency',
              linkage: {
                type: 'isoCurrencies',
                id: 'USD'
              }
            },
            employee: {
              self: '/expenseEntries/1/links/employee',
              related: '/expenseEntries/1/employee',
              linkage: {
                type: 'people',
                id: '3'
              }
            }
          }
        },
        links: {
          self: '/expenseEntries/1'
        },
        included: [
          {
            type: 'isoCurrencies',
            id: 'USD',
            attributes: {
              countryName: 'United States',
              name: 'United States Dollar',
              minorUnit: 'cent'
            },
            links: {
              self: '/isoCurrencies/USD'
            }
          },
          {
            type: 'people',
            id: '3',
            attributes: {
              email: 'lazy@xyz.fake',
              name: 'Lazy Author',
              dateJoined: '2013-10-31 17:25:00 -0400'
            },
            links: {
              self: '/people/3',
            }
          }
        ]
      },
      JSONAPI::ResourceSerializer.new(ExpenseEntryResource,
                                      include: ['iso_currency', 'employee'],
                                      fields: {people: [:id, :name, :email, :date_joined]}).serialize_to_hash(
        ExpenseEntryResource.new(@expense_entry))
    )
  end

  def test_serializer_empty_links_null_and_array
    planet_hash = JSONAPI::ResourceSerializer.new(PlanetResource).serialize_to_hash(
      PlanetResource.new(Planet.find(8)))

    assert_hash_equals(
      {
        data: {
          type: 'planets',
          id: '8',
          attributes: {
            name: 'Beta W',
            description: 'Newly discovered Planet W'
          },
          links: {
            self: '/planets/8',
            planetType: {
              self: '/planets/8/links/planetType',
              related: '/planets/8/planetType',
              linkage: nil
            },
            tags: {
              self: '/planets/8/links/tags',
              related: '/planets/8/tags'
            },
            moons: {
              self: '/planets/8/links/moons',
              related: '/planets/8/moons'
            }
          }
        },
        links: {
          self: '/planets/8'
        }
      }, planet_hash)
  end

  def test_serializer_include_with_empty_links_null_and_array
    planets = []
    Planet.find(7, 8).each do |planet|
      planets.push PlanetResource.new(planet)
    end

    planet_hash = JSONAPI::ResourceSerializer.new(PlanetResource,
                                                  include: ['planet_type'],
                                                  fields: { planet_types: [:id, :name] }).serialize_to_hash(planets)

    assert_hash_equals(
      {
        data: [{
          type: 'planets',
          id: '7',
          attributes: {
            name: 'Beta X',
            description: 'Newly discovered Planet Z'
          },
          links: {
            self: '/planets/7',
            planetType: {
              self: '/planets/7/links/planetType',
              related: '/planets/7/planetType',
              linkage: {
                type: 'planetTypes',
                id: '5'
              }
            },
            tags: {
              self: '/planets/7/links/tags',
              related: '/planets/7/tags'
            },
            moons: {
              self: '/planets/7/links/moons',
              related: '/planets/7/moons'
            }
          }
        },
        {
          type: 'planets',
          id: '8',
          attributes: {
            name: 'Beta W',
            description: 'Newly discovered Planet W'
          },
          links: {
            self: '/planets/8',
            planetType: {
              self: '/planets/8/links/planetType',
              related: '/planets/8/planetType',
              linkage: nil
            },
            tags: {
              self: '/planets/8/links/tags',
              related: '/planets/8/tags'
            },
            moons: {
              self: '/planets/8/links/moons',
              related: '/planets/8/moons'
            }
          }
        }
      ],
      links: {
        self: '/planets'
      },
      included: [
        {
          type: 'planetTypes',
          id: '5',
          attributes: {
            name: 'unknown'
          },
          links: {
            self: '/planetTypes/5'
          }
        }
      ]
    }, planet_hash)
  end

  def test_serializer_booleans
    JSONAPI.configuration.json_key_format = :underscored_key

    preferences = PreferencesResource.new(Preferences.find(1))

    assert_hash_equals(
      {
        data: {
          type: 'preferences',
          id: '1',
          attributes: {
            advanced_mode: false
          },
          links: {
            self: '/preferences/1',
            author: {
              self: '/preferences/1/links/author',
              related: '/preferences/1/author',
              linkage: nil
            },
            friends: {
              self: '/preferences/1/links/friends',
              related: '/preferences/1/friends'
            }
          }
        },
        links: {
          self: '/preferences/1'
        }
      },
      JSONAPI::ResourceSerializer.new(PreferencesResource).serialize_to_hash(preferences)
    )
  end

  def test_serializer_data_types
    JSONAPI.configuration.json_key_format = :underscored_key

    facts = FactResource.new(Fact.find(1))

    assert_hash_equals(
      {
        data: {
          type: 'facts',
          id: '1',
          attributes: {
            spouse_name: 'Jane Author',
            bio: 'First man to run across Antartica.',
            quality_rating: 23.89/45.6,
            salary: BigDecimal('47000.56', 30),
            date_time_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'),
            birthday: Date.parse('1965-06-30'),
            bedtime: Time.parse('2000-01-01 20:00:00 UTC +00:00'), #DB seems to set the date to 2001-01-01 for time types
            photo: "abc",
            cool: false
          },
          links: {
            self: '/facts/1'
          }
        },
        links: {
          self: '/facts/1'
        }
      },
      JSONAPI::ResourceSerializer.new(FactResource).serialize_to_hash(facts)
    )
  end
end
