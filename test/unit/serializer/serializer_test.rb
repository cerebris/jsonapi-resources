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

    serialized = JSONAPI::ResourceSerializer.new(
      PostResource,
      base_url: 'http://example.com').serialize_to_hash(PostResource.new(@post)
    )

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
              },
              data: nil
            },
            author: {
              links: {
                self: 'http://example.com/posts/1/relationships/author',
                related: 'http://example.com/posts/1/author'
              },
              data: {
                type: 'people',
                id: '1'
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
    assert_hash_equals(
      {
        data: nil
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
              },
              data: nil
            },
            writer: {
              links:{
                self: 'http://example.com/api/v1/posts/1/relationships/writer',
                related: 'http://example.com/api/v1/posts/1/writer'
              },
              data: {
                type: 'writers',
                id: '1'
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
              },
              data: {
                type: 'people',
                id: '1'
              }
            }
          }
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
              },
              data: nil
            },
            author: {
              links: {
                self: '/posts/1/relationships/author',
                related: '/posts/1/author'
              },
              data: {
                type: 'people',
                id: '1'
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
            id: '1',
            attributes: {
              name: 'Joe Author',
              email: 'joe@xyz.fake',
              dateJoined: '2013-08-07 16:25:00 -0400'
            },
            links: {
              self: '/people/1'
            },
            relationships: {
             comments: {
               links: {
                 self: '/people/1/relationships/comments',
                 related: '/people/1/comments'
               }
             },
             posts: {
               links: {
                 self: '/people/1/relationships/posts',
                 related: '/people/1/posts'
               }
             },
             preferences: {
               links: {
                 self: '/people/1/relationships/preferences',
                 related: '/people/1/preferences'
               },
               data: {
                 type: 'preferences',
                 id: '1'
               }
             },
             hairCut: {
               links: {
                 self: "/people/1/relationships/hairCut",
                 related: "/people/1/hairCut"
               },
               data: nil
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
            self: '/posts/1'
          },
          relationships: {
            section: {
              links: {
                self: '/posts/1/relationships/section',
                related: '/posts/1/section'
              },
              data: nil
            },
            author: {
              links: {
                self: '/posts/1/relationships/author',
                related: '/posts/1/author'
              },
              data: {
                type: 'people',
                id: '1'
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
            id: '1',
            attributes: {
              name: 'Joe Author',
              email: 'joe@xyz.fake',
              date_joined: '2013-08-07 16:25:00 -0400'
            },
            links: {
              self: '/people/1'
            },
            relationships: {
              comments: {
                links: {
                  self: '/people/1/relationships/comments',
                  related: '/people/1/comments'
                }
              },
              posts: {
                links: {
                  self: '/people/1/relationships/posts',
                  related: '/people/1/posts'
                }
              },
              preferences: {
                links: {
                  self: '/people/1/relationships/preferences',
                  related: '/people/1/preferences'
                },
                data: {
                  type: 'preferences',
                  id: '1'
                }
              },
              hair_cut: {
                links: {
                  self: '/people/1/relationships/hairCut',
                  related: '/people/1/hairCut'
                },
                data: nil
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
            self: '/posts/1'
          },
          relationships: {
            section: {
              links: {
                self: '/posts/1/relationships/section',
                related: '/posts/1/section'
              },
              data: nil
            },
            author: {
              links: {
                self: '/posts/1/relationships/author',
              related: '/posts/1/author'
              },
              data: {
                type: 'people',
                id: '1'
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
              },
              data: [
                {type: 'comments', id: '1'},
                {type: 'comments', id: '2'}
              ]
            }
          }
        },
        included: [
            {
              type: 'tags',
              id: '1',
              attributes: {
                name: 'short'
              },
              links: {
                self: '/tags/1'
              },
              relationships: {
                posts: {
                  links: {
                    self: '/tags/1/relationships/posts',
                    related: '/tags/1/posts'
                  }
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
                self: '/tags/2'
              },
              relationships: {
                posts: {
                  links: {
                    self: '/tags/2/relationships/posts',
                    related: '/tags/2/posts'
                  }
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
                self: '/tags/4'
              },
              relationships: {
                posts: {
                  links: {
                    self: '/tags/4/relationships/posts',
                    related: '/tags/4/posts'
                  },
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
                self: '/comments/1'
              },
              relationships: {
                author: {
                  links: {
                    self: '/comments/1/relationships/author',
                    related: '/comments/1/author'
                  },
                  data: {
                    type: 'people',
                    id: '1'
                  }
                },
                post: {
                  links: {
                    self: '/comments/1/relationships/post',
                    related: '/comments/1/post'
                  },
                  data: {
                    type: 'posts',
                    id: '1'
                  }
                },
                tags: {
                  links: {
                    self: '/comments/1/relationships/tags',
                    related: '/comments/1/tags'
                  },
                  data: [
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
                self: '/comments/2'
              },
              relationships: {
                author: {
                  links: {
                    self: '/comments/2/relationships/author',
                    related: '/comments/2/author'
                  },
                  data: {
                    type: 'people',
                    id: '2'
                  }
                },
                post: {
                  links: {
                    self: '/comments/2/relationships/post',
                    related: '/comments/2/post'
                  },
                  data: {
                    type: 'posts',
                    id: '1'
                  }
                },
                tags: {
                  links: {
                    self: '/comments/2/relationships/tags',
                    related: '/comments/2/tags'
                  },
                  data: [
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
            self: '/people/2'
          },
          relationships: {
            posts: {
              links: {
                self: '/people/2/relationships/posts',
                related: '/people/2/posts'
              }
            },
            comments: {
              links: {
                self: '/people/2/relationships/comments',
                related: '/people/2/comments'
              },
              data: [
                {type: 'comments', id: '2'},
                {type: 'comments', id: '3'}
              ]
            },
            preferences: {
              links: {
                self: "/people/2/relationships/preferences",
                related: "/people/2/preferences"
              },
              data: nil
            },
            hairCut: {
              links: {
                self: "/people/2/relationships/hairCut",
                related: "/people/2/hairCut"
              },
              data: nil
            }
          }
        },
        included: [
          {
            type: 'comments',
            id: '2',
            attributes: {
              body: 'i liked it'
            },
            links: {
              self: '/comments/2'
            },
            relationships: {
              author: {
                links: {
                  self: '/comments/2/relationships/author',
                  related: '/comments/2/author'
                },
                data: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                links: {
                  self: '/comments/2/relationships/post',
                  related: '/comments/2/post'
                },
                data: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                links: {
                  self: '/comments/2/relationships/tags',
                  related: '/comments/2/tags'
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
              self: '/comments/3'
            },
            relationships: {
              author: {
                links: {
                  self: '/comments/3/relationships/author',
                  related: '/comments/3/author'
                },
                data: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                links: {
                  self: '/comments/3/relationships/post',
                  related: '/comments/3/post'
                },
                data: {
                  type: 'posts',
                  id: '2'
                }
              },
              tags: {
                links: {
                  self: '/comments/3/relationships/tags',
                  related: '/comments/3/tags'
                }
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
              self: '/posts/1'
            },
            relationships: {
              section: {
                links: {
                  self: '/posts/1/relationships/section',
                  related: '/posts/1/section'
                },
                data: nil
              },
              author: {
                links: {
                  self: '/posts/1/relationships/author',
                  related: '/posts/1/author'
                },
                data: {
                  type: 'people',
                  id: '1'
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
                },
                data: [
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
              self: '/posts/2'
            },
            relationships: {
              section: {
                links: {
                  self: '/posts/2/relationships/section',
                  related: '/posts/2/section'
                },
                data: {
                  type: 'sections',
                  id: '2'
                }
              },
              author: {
                links: {
                  self: '/posts/2/relationships/author',
                  related: '/posts/2/author'
                },
                data: {
                  type: 'people',
                  id: '1'
                }
              },
              tags: {
                links: {
                  self: '/posts/2/relationships/tags',
                  related: '/posts/2/tags'
                }
              },
              comments: {
                links: {
                  self: '/posts/2/relationships/comments',
                  related: '/posts/2/comments'
                },
                data: [
                  {type: 'comments', id: '3'}
                ]
              }
            }
          }
        ],
        included: [
          {
            type: 'tags',
            id: '1',
            attributes: {
              name: 'short'
            },
            links: {
              self: '/tags/1'
            },
            relationships: {
              posts: {
                links: {
                  self: '/tags/1/relationships/posts',
                  related: '/tags/1/posts'
                }
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
              self: '/tags/2'
            },
            relationships: {
              posts: {
                links: {
                  self: '/tags/2/relationships/posts',
                  related: '/tags/2/posts'
                }
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
              self: '/tags/4'
            },
            relationships: {
              posts: {
                links: {
                  self: '/tags/4/relationships/posts',
                  related: '/tags/4/posts'
                }
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
              self: '/tags/5'
            },
            relationships: {
              posts: {
                links: {
                  self: '/tags/5/relationships/posts',
                  related: '/tags/5/posts'
                }
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
              self: '/comments/1'
            },
            relationships: {
              author: {
                links: {
                  self: '/comments/1/relationships/author',
                  related: '/comments/1/author'
                },
                data: {
                  type: 'people',
                  id: '1'
                }
              },
              post: {
                links: {
                  self: '/comments/1/relationships/post',
                  related: '/comments/1/post'
                },
                data: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                links: {
                  self: '/comments/1/relationships/tags',
                  related: '/comments/1/tags'
                },
                data: [
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
              self: '/comments/2'
            },
            relationships: {
              author: {
                links: {
                  self: '/comments/2/relationships/author',
                  related: '/comments/2/author'
                },
                data: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                links: {
                  self: '/comments/2/relationships/post',
                  related: '/comments/2/post'
                },
                data: {
                  type: 'posts',
                  id: '1'
                }
              },
              tags: {
                links: {
                  self: '/comments/2/relationships/tags',
                  related: '/comments/2/tags'
                },
                data: [
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
              self: '/comments/3'
            },
            relationships: {
              author: {
                links: {
                  self: '/comments/3/relationships/author',
                  related: '/comments/3/author'
                },
                data: {
                  type: 'people',
                  id: '2'
                }
              },
              post: {
                links: {
                  self: '/comments/3/relationships/post',
                  related: '/comments/3/post'
                },
                data: {
                  type: 'posts',
                  id: '2'
                }
              },
              tags: {
                links: {
                  self: '/comments/3/relationships/tags',
                  related: '/comments/3/tags'
                },
                data: [
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
              self: '/posts/1'
            }
          },
          {
            type: 'posts',
            id: '2',
            attributes: {
              title: 'JR Solves your serialization woes!'
            },
            links: {
              self: '/posts/2'
            }
          }
        ],
        included: [
          {
            type: 'posts',
            id: '11',
            attributes: {
              title: 'JR How To'
            },
            links: {
              self: '/posts/11'
            }
          },
          {
            type: 'people',
            id: '1',
            attributes: {
              email: 'joe@xyz.fake'
            },
            links: {
              self: '/people/1'
            },
            relationships: {
              comments: {
                links: {
                  self: '/people/1/relationships/comments',
                  related: '/people/1/comments'
                }
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
              self: '/comments/1'
            },
            relationships: {
              post: {
                links: {
                  self: '/comments/1/relationships/post',
                  related: '/comments/1/post'
                },
                data: {
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
              self: '/comments/2'
            },
            relationships: {
              post: {
                links: {
                  self: '/comments/2/relationships/post',
                  related: '/comments/2/post'
                },
                data: {
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
              self: '/comments/3'
            },
            relationships: {
              post: {
                links: {
                  self: '/comments/3/relationships/post',
                  related: '/comments/3/post'
                },
                data: {
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
                                        posts: [:id, :title],
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
            self: '/expenseEntries/1'
          },
          relationships: {
            isoCurrency: {
              links: {
                self: '/expenseEntries/1/relationships/isoCurrency',
                related: '/expenseEntries/1/isoCurrency'
              },
              data: {
                type: 'isoCurrencies',
                id: 'USD'
              }
            },
            employee: {
              links: {
                self: '/expenseEntries/1/relationships/employee',
                related: '/expenseEntries/1/employee'
              },
              data: {
                type: 'people',
                id: '3'
              }
            }
          }
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
            self: '/planets/8'
          },
          relationships: {
            planetType: {
              links: {
                self: '/planets/8/relationships/planetType',
                related: '/planets/8/planetType'
              },
              data: nil
            },
            tags: {
              links: {
                self: '/planets/8/relationships/tags',
                related: '/planets/8/tags'
              }
            },
            moons: {
              links: {
                self: '/planets/8/relationships/moons',
                related: '/planets/8/moons'
              }
            }
          }
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
            self: '/planets/7'
          },
          relationships: {
            planetType: {
              links: {
                self: '/planets/7/relationships/planetType',
                related: '/planets/7/planetType'
              },
              data: {
                type: 'planetTypes',
                id: '5'
              }
            },
            tags: {
              links: {
                self: '/planets/7/relationships/tags',
                related: '/planets/7/tags'
              }
            },
            moons: {
              links: {
                self: '/planets/7/relationships/moons',
                related: '/planets/7/moons'
              }
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
            self: '/planets/8'
          },
          relationships: {
            planetType: {
              links: {
                self: '/planets/8/relationships/planetType',
                related: '/planets/8/planetType'
              },
              data: nil
            },
            tags: {
              links: {
                self: '/planets/8/relationships/tags',
                related: '/planets/8/tags'
              }
            },
            moons: {
              links: {
                self: '/planets/8/relationships/moons',
                related: '/planets/8/moons'
              }
            }
          }
        }
      ],
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
            self: '/preferences/1'
          },
          relationships: {
            author: {
              links: {
                self: '/preferences/1/relationships/author',
                related: '/preferences/1/author'
              },
              data: nil
            },
            friends: {
              links: {
                self: '/preferences/1/relationships/friends',
                related: '/preferences/1/friends'
              }
            }
          }
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
        }
      },
      JSONAPI::ResourceSerializer.new(FactResource).serialize_to_hash(facts)
    )
  end
end
