require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class RequestTest < ActionDispatch::IntegrationTest

  def test_get
    get '/posts'
    assert_equal 200, status
  end

  def test_put_single
    put '/posts/3',
        {
          'posts' => {
            'id' => '3',
            'title' => 'A great new Post',
            'links' => {
              'tags' => [3, 4]
            }
          }
        }
    assert_equal 200, status
  end

  def test_destroy_single
    delete '/posts/7'
    assert_equal 204, status
  end

  def test_destroy_multiple
    delete '/posts/8,9'
    assert_equal 204, status
  end
end
