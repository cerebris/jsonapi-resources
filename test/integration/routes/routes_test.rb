require File.expand_path('../../../test_helper', __FILE__)

class RoutesTest < ActionDispatch::IntegrationTest

  def test_routing_post
    assert_routing({ path: 'posts', method: :post }, { controller: 'posts', action: 'create' })
  end

  def test_routing_put
    assert_routing({ path: '/posts/1', method: :put }, { controller: 'posts', action: 'update', id: '1' })
  end

  def test_routing_posts_show
    assert_routing({ path: '/posts/1', method: :get }, {action: 'show', controller: 'posts', id: '1'})
  end

  def test_routing_posts_links_author_show
    assert_routing({ path: '/posts/1/links/author', method: :get }, { controller: 'posts', action: 'show_association', post_id: '1', association: 'author' })
  end

  def test_routing_posts_links_author_destroy
    assert_routing({ path: '/posts/1/links/author', method: :delete }, { controller: 'posts', action: 'destroy_association', post_id: '1', association: 'author' })
  end

  def test_routing_posts_links_author_create
    assert_routing({ path: '/posts/1/links/author', method: :post }, { controller: 'posts', action: 'create_association', post_id: '1', association: 'author' })
  end

  def test_routing_posts_links_tags_show
    assert_routing({ path: '/posts/1/links/tags', method: :get }, { controller: 'posts', action: 'show_association', post_id: '1', association: 'tags' })
  end

  def test_routing_posts_links_tags_destroy
    assert_routing({ path: '/posts/1/links/tags/1,2', method: :delete }, { controller: 'posts', action: 'destroy_association', post_id: '1', keys: '1,2', association: 'tags' })
  end

  def test_routing_posts_links_tags_update
    assert_routing({ path: '/posts/1/links/tags', method: :post }, { controller: 'posts', action: 'create_association', post_id: '1', association: 'tags' })
  end

  # V1
  def test_routing_v1_posts_show
    assert_routing({ path: '/api/v1/posts/1', method: :get }, {action: 'show', controller: 'api/v1/posts', id: '1'})
  end

  def test_routing_v1_posts_delete
    assert_routing({ path: '/api/v1/posts/1', method: :delete }, {action: 'destroy', controller: 'api/v1/posts', id: '1'})
  end

  def test_routing_v1_posts_links_author_show
    assert_routing({ path: '/api/v1/posts/1/links/author', method: :get }, { controller: 'api/v1/posts', action: 'show_association', post_id: '1', association: 'author' })
  end

  # V2
  def test_routing_v2_posts_show
    assert_routing({ path: '/api/v2/authors/1', method: :get }, {action: 'show', controller: 'api/v2/authors', id: '1'})
  end

  def test_routing_v2_posts_links_author_show
    assert_routing({ path: '/api/v2/posts/1/links/author', method: :get }, { controller: 'api/v2/posts', action: 'show_association', post_id: '1', association: 'author' })
  end

  def test_routing_v2_preferences_show
    assert_routing({ path: '/api/v2/preferences', method: :get }, {action: 'show', controller: 'api/v2/preferences'})
  end

  # V3
  def test_routing_v3_posts_show
    assert_routing({ path: '/api/v3/posts/1', method: :get }, {action: 'show', controller: 'api/v3/posts', id: '1'})
  end

  # ToDo: Refute routing
  # def test_routing_v3_posts_delete
  #   assert_routing({ path: '/api/v3/posts/1', method: :delete }, {action: 'destroy', controller: 'api/v3/posts', id: '1'})
  # end

end

