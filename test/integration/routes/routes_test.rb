require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class RoutesTest < ActionDispatch::IntegrationTest

  def test_routing_post
    assert_routing({ path: 'posts', method: :post }, { controller: 'posts', action: 'create' })
  end

  def test_routing_put
    assert_routing({ path: '/posts/1', method: :put }, { controller: 'posts', action: 'update', id: '1' })
  end

end

