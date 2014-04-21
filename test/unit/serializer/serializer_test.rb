require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)
require 'json/api/resource_serializer'


class SerializerTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
    @fred = Person.find_by(name: 'Fred Reader')
  end

  def test_serializer
    assert_hash_equals({
                  posts: [{
                    id: 1,
                    title: 'New post',
                    body: 'A body!!!',
                    subject: 'New post',
                    links: {
                      author: 1,
                      tags: [1,2,3],
                      comments: [1,2]
                    }
                  }]
                 }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post)))
  end

  def test_serializer_limited_fieldset
    assert_hash_equals({
                   posts: [{
                     id: 1,
                     title: 'New post',
                     links: {
                       author: 1
                     }
                   }]
                }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post),
                                                               fields: {posts: [:id, :title, :author]}))
  end

  def test_serializer_include
    assert_hash_equals({
                  posts: [{
                    id: 1,
                    title: 'New post',
                    body: 'A body!!!',
                    subject: 'New post',
                    links: {
                      author: 1,
                      tags: [1,2,3],
                      comments: [1,2]
                    }
                  }],
                  linked: {
                    people: [{
                              id: 1,
                              name: 'Joe Author',
                              email: 'joe@xyz.fake',
                              date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'),
                              links: {
                                  comments: [1],
                                  posts: [1,2]
                              }
                             }]
                  }
                 }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post), include: [:author]))
  end

  def test_serializer_include_sub_objects
    assert_hash_equals(
        {
          posts: [{
            id: 1,
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post',
            links: {
              author: 1,
              tags: [1,2,3],
              comments: [1,2]
            }
          }],
          linked: {
            tags: [
                {
                  id: 1,
                  name: 'short'
                },
                {
                  id: 2,
                  name: 'whiny'
                },
                {
                  id: 4,
                  name: 'happy'
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
         }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post), include: [:comments,'comments.tags']))
  end

  def test_serializer_include_has_many_sub_objects_only
    assert_hash_equals(
        {
          posts: [{
            id: 1,
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post',
            links: {
              author: 1,
              tags: [1,2,3],
              comments: [1,2]
            }
          }],
          linked: {
            tags: [
                {
                  id: 1,
                  name: 'short'
                },
                {
                  id: 2,
                  name: 'whiny'
                },
                {
                  id: 4,
                  name: 'happy'
                }
            ]
          }
         }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post), include: ['comments.tags']))
  end

  def test_serializer_include_has_one_sub_objects_only
    assert_hash_equals(
        {
          posts: [{
            id: 1,
            title: 'New post',
            body: 'A body!!!',
            subject: 'New post',
            links: {
              author: 1,
              tags: [1,2,3],
              comments: [1,2]
            }
          }],
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
         }, JSON::API::ResourceSerializer.new.serialize(PostResource.new(@post), include: ['author.comments']))
  end

  def test_serializer_different_foreign_key
    assert_hash_equals(
        {
          people: [{
            id: 2,
            name: 'Fred Reader',
            email: 'fred@xyz.fake',
            date_joined: DateTime.parse('2013-10-31 20:25:00 UTC +00:00'),
            links: {
              posts: [],
              comments: [2,3]
            }
          }],
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
                body: 'Thanks man. Great post. But what is AMS?',
                links: {
                  author: 2,
                  post: 2,
                  tags: [5]
                }
              }
              ]
          }
         }, JSON::API::ResourceSerializer.new.serialize(PersonResource.new(@fred), include: ['comments']))
  end

  def test_serializer_array_of_resources

    posts = []
    Post.all.each do |post|
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
              tags: [1,2,3],
              comments: [1,2]
            }
          },
          {
            id: 2,
            title: 'AMS Solves your serialization wows!',
            body: 'Use AMS',
            subject: 'AMS Solves your serialization wows!',
            links: {
              author: 1,
              tags: [5],
              comments: [3]
            }
          }],
          linked: {
            tags: [
                {
                  id: 1,
                  name: 'short'
                },
                {
                  id: 2,
                  name: 'whiny'
                },
                {
                  id: 4,
                  name: 'happy'
                },
                {
                  id: 5,
                  name: 'AMS'
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
                    body: 'Thanks man. Great post. But what is AMS?',
                    links: {
                      author: 2,
                      post: 2,
                      tags: [5]
                    }
                }
            ]
          }
         }, JSON::API::ResourceSerializer.new.serialize(posts, include: ['comments','comments.tags']))
  end

  def test_serializer_array_of_resources_limited_fields

    posts = []
    Post.all.each do |post|
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
                        title: 'AMS Solves your serialization wows!',
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
                        name: 'AMS'
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
                        body: 'Thanks man. Great post. But what is AMS?',
                        links: {
                            post: 2
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
                    }],
                posts: [{
                            id: 1,
                            title: 'New post',
                            links: {
                                author: 1
                            }
                        },
                        {
                            id: 2,
                            title: 'AMS Solves your serialization wows!',
                            links: {
                                author: 1
                            }
                        }]
            }
        }, JSON::API::ResourceSerializer.new.serialize(posts, include: ['comments','author','comments.tags','author.posts'],
                                                       fields: {
                                                           people: [:id, :email, :comments],
                                                           posts: [:id, :title, :author],
                                                           tags: [:name],
                                                           comments: [:id, :body, :post]
                                                        }))
  end
end
