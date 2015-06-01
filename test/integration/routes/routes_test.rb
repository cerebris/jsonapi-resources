require File.expand_path('../../../test_helper', __FILE__)

class RoutesTest < ActionDispatch::IntegrationTest

  def test_routing_post
    assert_routing({path: 'posts', method: :post},
                   {controller: 'posts', action: 'create'})
  end

  def test_routing_patch
    assert_routing({path: '/posts/1', method: :patch},
                   {controller: 'posts', action: 'update', id: '1'})
  end

  def test_routing_posts_show
    assert_routing({path: '/posts/1', method: :get},
                   {action: 'show', controller: 'posts', id: '1'})
  end

  def test_routing_posts_links_author_show
    assert_routing({path: '/posts/1/relationships/author', method: :get},
                   {controller: 'posts', action: 'show_association', post_id: '1', association: 'author'})
  end

  def test_routing_posts_links_author_destroy
    assert_routing({path: '/posts/1/relationships/author', method: :delete},
                   {controller: 'posts', action: 'destroy_association', post_id: '1', association: 'author'})
  end

  def test_routing_posts_links_author_update
    assert_routing({path: '/posts/1/relationships/author', method: :patch},
                   {controller: 'posts', action: 'update_association', post_id: '1', association: 'author'})
  end

  def test_routing_posts_links_tags_show
    assert_routing({path: '/posts/1/relationships/tags', method: :get},
                   {controller: 'posts', action: 'show_association', post_id: '1', association: 'tags'})
  end

  def test_routing_posts_links_tags_destroy
    assert_routing({path: '/posts/1/relationships/tags/1,2', method: :delete},
                   {controller: 'posts', action: 'destroy_association', post_id: '1', keys: '1,2', association: 'tags'})
  end

  def test_routing_posts_links_tags_create
    assert_routing({path: '/posts/1/relationships/tags', method: :post},
                   {controller: 'posts', action: 'create_association', post_id: '1', association: 'tags'})
  end

  def test_routing_posts_links_tags_update_acts_as_set
    assert_routing({path: '/posts/1/relationships/tags', method: :patch},
                   {controller: 'posts', action: 'update_association', post_id: '1', association: 'tags'})
  end

  # V1
  def test_routing_v1_posts_show
    assert_routing({path: '/api/v1/posts/1', method: :get},
                   {action: 'show', controller: 'api/v1/posts', id: '1'})
  end

  def test_routing_v1_posts_delete
    assert_routing({path: '/api/v1/posts/1', method: :delete},
                   {action: 'destroy', controller: 'api/v1/posts', id: '1'})
  end

  def test_routing_v1_posts_links_writer_show
    assert_routing({path: '/api/v1/posts/1/relationships/writer', method: :get},
                   {controller: 'api/v1/posts', action: 'show_association', post_id: '1', association: 'writer'})
  end

  # V2
  def test_routing_v2_posts_links_author_show
    assert_routing({path: '/api/v2/posts/1/relationships/author', method: :get},
                   {controller: 'api/v2/posts', action: 'show_association', post_id: '1', association: 'author'})
  end

  def test_routing_v2_preferences_show
    assert_routing({path: '/api/v2/preferences', method: :get},
                   {action: 'show', controller: 'api/v2/preferences'})
  end

  # V3
  def test_routing_v3_posts_show
    assert_routing({path: '/api/v3/posts/1', method: :get},
                   {action: 'show', controller: 'api/v3/posts', id: '1'})
  end

  # V4 camelCase
  def test_routing_v4_posts_show
    assert_routing({path: '/api/v4/posts/1', method: :get},
                   {action: 'show', controller: 'api/v4/posts', id: '1'})
  end

  def test_routing_v4_isoCurrencies_resources
    assert_routing({path: '/api/v4/isoCurrencies/USD', method: :get},
                   {action: 'show', controller: 'api/v4/iso_currencies', id: 'USD'})
  end

  def test_routing_v4_expenseEntries_resources
    assert_routing({path: '/api/v4/expenseEntries/1', method: :get},
                   {action: 'show', controller: 'api/v4/expense_entries', id: '1'})

    assert_routing({path: '/api/v4/expenseEntries/1/relationships/isoCurrency', method: :get},
                   {controller: 'api/v4/expense_entries', action: 'show_association', expense_entry_id: '1', association: 'iso_currency'})
  end

  # V5 dasherized
  def test_routing_v5_posts_show
    assert_routing({path: '/api/v5/posts/1', method: :get},
                   {action: 'show', controller: 'api/v5/posts', id: '1'})
  end

  def test_routing_v5_isoCurrencies_resources
    assert_routing({path: '/api/v5/iso-currencies/USD', method: :get},
                   {action: 'show', controller: 'api/v5/iso_currencies', id: 'USD'})
  end

  def test_routing_v5_expenseEntries_resources
    assert_routing({path: '/api/v5/expense-entries/1', method: :get},
                   {action: 'show', controller: 'api/v5/expense_entries', id: '1'})

    assert_routing({path: '/api/v5/expense-entries/1/relationships/iso-currency', method: :get},
                   {controller: 'api/v5/expense_entries', action: 'show_association', expense_entry_id: '1', association: 'iso_currency'})
  end

  def test_routing_authors_show
    assert_routing({path: '/api/v5/authors/1', method: :get},
                   {action: 'show', controller: 'api/v5/authors', id: '1'})
  end

  def test_routing_author_links_posts_create_not_acts_as_set
    assert_routing({path: '/api/v5/authors/1/relationships/posts', method: :post},
                   {controller: 'api/v5/authors', action: 'create_association', author_id: '1', association: 'posts'})
  end

  #primary_key
  def test_routing_primary_key_jsonapi_resources
    assert_routing({path: '/iso_currencies/USD', method: :get},
                   {action: 'show', controller: 'iso_currencies', id: 'USD'})
  end

  # ToDo: Refute routing
  # def test_routing_v3_posts_delete
  #   assert_routing({ path: '/api/v3/posts/1', method: :delete },
  #                  {action: 'destroy', controller: 'api/v3/posts', id: '1'})
  # end

  # def test_routing_posts_links_author_except_destroy
  #   assert_routing({ path: '/api/v3/posts/1/relationships/author', method: :delete },
  #                  { controller: 'api/v3/posts', action: 'destroy_association', post_id: '1', association: 'author' })
  # end
  #
  # def test_routing_posts_links_tags_only_create_show
  #   assert_routing({ path: '/api/v3/posts/1/relationships/tags/1,2', method: :delete },
  #                  { controller: 'api/v3/posts', action: 'destroy_association', post_id: '1', keys: '1,2', association: 'tags' })
  # end

  # Test that non acts as set has_many association update route is not created

end
