require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class SerializerTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
    @fred = Person.find_by(name: 'Fred Reader')
  end

  def test_serializer
    assert_equal({
                  posts: {
                    id: 1,
                    title: 'New post',
                    body: 'A body!!!',
                    subject: 'New post',
                    links: {
                      author: 1,
                      tags: [1,2],
                      comments: [1,2]
                    }
                  }
                 }, PostResource.new(@post).as_json)
  end

  def test_serializer_include
    assert_equal({
                  posts: {
                    id: 1,
                    title: 'New post',
                    body: 'A body!!!',
                    subject: 'New post',
                    links: {
                      author: 1,
                      tags: [1,2],
                      comments: [1,2]
                    }
                  },
                  linked: {
                    people: [{
                              id: 1,
                              name: 'Joe Author',
                              email: 'joe@xyz.fake',
                              date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'),
                              links: {
                                  comments: [1],
                                  posts: [1]
                              }
                             }]
                  }
                 }, PostResource.new(@post, include: 'author').as_json)
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
              tags: [1,2],
              comments: [1,2]
            }
          },
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
                  id: 3,
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
                      tags: [3, 1]
                    }
                }
            ]
          }
         }, PostResource.new(@post, include: 'comments,comments.tags').as_json)
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
              tags: [1,2],
              comments: [1,2]
            }
            },
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
                  id: 3,
                  name: 'happy'
                }
            ]
          }
         }, PostResource.new(@post, include: 'comments.tags').as_json)
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
              tags: [1,2],
              comments: [1,2]
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
         }, PostResource.new(@post, include: 'author.comments').as_json)
  end

  def test_serializer_different_foreign_key
    assert_hash_equals(
        {
          people: {
            id: 2,
            name: 'Fred Reader',
            email: 'fred@xyz.fake',
            date_joined: DateTime.parse('2013-10-31 20:25:00 UTC +00:00'),
            links: {
              posts: [],
              comments: [2]
            }
            },
          linked: {
              comments: [
                 {
                      id: 2,
                      body: 'i liked it',
                      links: {
                        author: 2,
                        post: 1,
                        tags: [3, 1]
                      }
                  }
              ]
          }
         }, PersonResource.new(@fred, include: 'comments').as_json)
  end
end
