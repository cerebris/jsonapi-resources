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
                              date_joined: '2013-08-07 20:25:00 UTC +00:00'
                             }]
                  }
                 }, PostResource.new(@post, include: 'post.author').as_json)
  end
end
