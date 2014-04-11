require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class SerializerTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
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
                              date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00')
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
                        post: 1,
                        tags: [2, 1]
                    }
                },
                {
                    id: 2,
                    body: 'i liked it',
                    links: {
                        post: 1,
                        tags: [3, 1]
                    }
                }
            ]
          }
         }, PostResource.new(@post, include: 'comments,comments.tags').as_json)
  end

  def test_serializer_include_sub_objects_only
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
end
