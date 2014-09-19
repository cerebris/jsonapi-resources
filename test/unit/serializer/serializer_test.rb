require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)
require 'jsonapi-resources'
require 'json'

class SerializerTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.find(1)
    @fred = Person.find_by(name: 'Fred Reader')

    @expense_entry = ExpenseEntry.find(1)
  end

  def test_serializer

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            section: nil,
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2]
          }
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post)))
  end

  def test_serializer_limited_fieldset

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          links: {
            author: 1
          }
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post),
        fields: {posts: [:id, :title, :author]}))
  end

  def test_serializer_include

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2],
            section: nil
          }
        },
        linked: {
          people: [{
                     id: 1,
                     name: 'Joe Author',
                     email: 'joe@xyz.fake',
                     dateJoined: '2013-08-07 16:25:00 -0400',
                     links: {
                       comments: [1],
                       posts: [1, 2, 11]
                     }
                   }]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post), include: [:author]))
  end

  def test_serializer_key_format

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2],
            section: nil
          }
        },
        linked: {
          people: [{
                     id: 1,
                     name: 'Joe Author',
                     email: 'joe@xyz.fake',
                     date_joined: '2013-08-07 16:25:00 -0400',
                     links: {
                       comments: [1],
                       posts: [1, 2, 11]
                     }
                   }]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post),
        include: [:author],
        key_formatter: UnderscoredKeyFormatter))
  end

  def test_serializer_include_sub_objects

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2],
            section: nil
          }
        },
        linked: {
          tags: [
            {
              id: 1,
              name: 'short',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 2,
              name: 'whiny',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 4,
              name: 'happy',
              links: {
                posts: :not_nil
              }
            }
          ],
          comments: [
            {
              id: 1,
              body: 'what a dumb post',
              links: {
                author: 1,
                post: 1,
                tags: [2, 1]
              }
            },
            {
              id: 2,
              body: 'i liked it',
              links: {
                author: 2,
                post: 1,
                tags: [4, 1]
              }
            }
          ]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post), include: [:comments, 'comments.tags']))
  end

  def test_serializer_include_has_many_sub_objects_only

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2],
            section: nil
          }
        },
        linked: {
          tags: [
            {
              id: 1,
              name: 'short',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 2,
              name: 'whiny',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 4,
              name: 'happy',
              links: {
                posts: :not_nil
              }
            }
          ]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post), include: ['comments.tags']))
  end

  def test_serializer_include_has_one_sub_objects_only

    assert_hash_equals(
      {
        posts: {
          id: 1,
          title: 'New post',
          body: 'A body!!!',
          subject: 'New post',
          links: {
            author: 1,
            tags: [1, 2, 3],
            comments: [1, 2],
            section: nil
          }
        },
        linked: {
          comments: [
            {
              id: 1,
              body: 'what a dumb post',
              links: {
                author: 1,
                post: 1,
                tags: [2, 1]
              }
            }
          ]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PostResource.new(@post), include: ['author.comments']))
  end

  def test_serializer_different_foreign_key

    assert_hash_equals(
      {
        people: {
          id: 2,
          name: 'Fred Reader',
          email: 'fred@xyz.fake',
          dateJoined: '2013-10-31 16:25:00 -0400',
          links: {
            posts: [],
            comments: [2, 3]
          }
        },
        linked: {
          comments: [{
                       id: 2,
                       body: 'i liked it',
                       links: {
                         author: 2,
                         post: 1,
                         tags: [4, 1]
                       }
                     },
                     {
                       id: 3,
                       body: 'Thanks man. Great post. But what is JR?',
                       links: {
                         author: 2,
                         post: 2,
                         tags: [5]
                       }
                     }
          ]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        PersonResource.new(@fred), include: ['comments']))
  end

  def test_serializer_array_of_resources

    posts = []
    Post.find(1, 2).each do |post|
      posts.push PostResource.new(post)
    end

    assert_hash_equals(
      {
        posts: [{
                  id: 1,
                  title: 'New post',
                  body: 'A body!!!',
                  subject: 'New post',
                  links: {
                    author: 1,
                    tags: [1, 2, 3],
                    comments: [1, 2],
                    section: nil
                  }
                },
                {
                  id: 2,
                  title: 'JR Solves your serialization woes!',
                  body: 'Use JR',
                  subject: 'JR Solves your serialization woes!',
                  links: {
                    author: 1,
                    tags: [5],
                    comments: [3],
                    section: 3
                  }
                }],
        linked: {
          tags: [
            {
              id: 1,
              name: 'short',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 2,
              name: 'whiny',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 4,
              name: 'happy',
              links: {
                posts: :not_nil
              }
            },
            {
              id: 5,
              name: 'JR',
              links: {
                posts: [2, 11]
              }
            }
          ],
          comments: [
            {
              id: 1,
              body: 'what a dumb post',
              links: {
                author: 1,
                post: 1,
                tags: [2, 1]
              }
            },
            {
              id: 2,
              body: 'i liked it',
              links: {
                author: 2,
                post: 1,
                tags: [4, 1]
              }
            },
            {
              id: 3,
              body: 'Thanks man. Great post. But what is JR?',
              links: {
                author: 2,
                post: 2,
                tags: [5]
              }
            }
          ]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        posts, include: ['comments', 'comments.tags']))
  end

  def test_serializer_array_of_resources_limited_fields

    posts = []
    Post.find(1, 2).each do |post|
      posts.push PostResource.new(post)
    end

    assert_hash_equals(
      {
        posts: [{
                  id: 1,
                  title: 'New post',
                  links: {
                    author: 1
                  }
                },
                {
                  id: 2,
                  title: 'JR Solves your serialization woes!',
                  links: {
                    author: 1
                  }
                }],
        linked: {
          tags: [
            {
              name: 'short'
            },
            {
              name: 'whiny'
            },
            {
              name: 'happy'
            },
            {
              name: 'JR'
            }
          ],
          comments: [
            {
              id: 1,
              body: 'what a dumb post',
              links: {
                post: 1
              }
            },
            {
              id: 2,
              body: 'i liked it',
              links: {
                post: 1
              }
            },
            {
              id: 3,
              body: 'Thanks man. Great post. But what is JR?',
              links: {
                post: 2
              }
            }
          ],
          posts: [
            {
              id: 11,
              title: 'JR How To',
              links: {
                author: 1
              }
            }
          ],
          people: [
            {
              id: 1,
              email: 'joe@xyz.fake',
              links: {
                comments: [1]
              }
            }]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        posts,
        include: ['comments', 'author', 'comments.tags', 'author.posts'],
        fields: {
          people: [:id, :email, :comments],
          posts: [:id, :title, :author],
          tags: [:name],
          comments: [:id, :body, :post]
        }))
  end

  def test_serializer_camelized_with_value_formatters
    assert_hash_equals(
      {
        expenseEntries: {
          id: 1,
          transactionDate: '04/15/2014',
          cost: '12.05',
          links: {
            isoCurrency: 'USD',
            employee: 3
          }
        },
        linked: {
          isoCurrencies: [{
                            code: 'USD',
                            countryName: 'United States',
                            name: 'United States Dollar',
                            minorUnit: 'cent'
                          }],
          people: [{
                     id: 3,
                     name: 'Lazy Author',
                     email: 'lazy@xyz.fake',
                     dateJoined: '2013-10-31 17:25:00 -0400',
                   }]
        }
      },
      JSONAPI::ResourceSerializer.new.serialize_to_hash(
        ExpenseEntryResource.new(@expense_entry),
        include: ['iso_currency', 'employee'],
        fields: {people: [:id, :name, :email, :date_joined]}
      )
    )
  end

  def test_serializer_empty_links_null_and_array
    planet_hash = JSONAPI::ResourceSerializer.new.serialize_to_hash(PlanetResource.new(Planet.find(8)))

    assert_hash_equals(
      {
        planets: {
          id: 8,
          name: 'Beta W',
          description: 'Newly discovered Planet W',
          links: {
            planetType: nil,
            tags: [],
            moons: []
          }
        }
      }, planet_hash)

    json = planet_hash.to_json
    assert_match /\"planetType\":null/, json
    assert_match /\"moons\":\[\]/, json
  end
end
