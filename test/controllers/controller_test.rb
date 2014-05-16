require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/active_record', __FILE__)

class PostsControllerTest < ActionController::TestCase

  def test_index
    get :index
    assert_response :success
  end

  def test_index_filter_by_id
    get :index, {id: 1}
    assert_response :success
  end

  def test_index_filter_by_title
    get :index, {title: 'New post'}
    assert_response :success
  end

  def test_index_filter_by_ids
    get :index, {ids: [1,2]}
    assert_response :success
    assert_equal 2, json_response['posts'].size
  end

  def test_index_filter_by_ids_and_include_related
    get :index, {ids: [2], include: [:comments]}
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 1, json_response['linked']['comments'].size
  end

  def test_index_filter_by_ids_and_include_related_different_type
    get :index, {ids: [1,2], include: [:author]}
    assert_response :success
    assert_equal 2, json_response['posts'].size
    assert_equal 1, json_response['linked']['people'].size
  end

  def test_index_filter_by_ids_and_fields
    get :index, {ids: [1,2], fields: {posts: [:id, :title, :author]}}
    assert_response :success
    assert_equal 2, json_response['posts'].size

    # id, title, links
    assert_equal 3, json_response['posts'][0].size
    assert json_response['posts'][0].has_key?('id')
    assert json_response['posts'][0].has_key?('title')
    assert json_response['posts'][0].has_key?('links')
  end

  def test_index_filter_by_ids_and_fields_2
    get :index, {ids: [1,2], fields: {posts: [:author]}}
    assert_response :success
    assert_equal 2, json_response['posts'].size

    # links
    assert_equal 1, json_response['posts'][0].size
    assert json_response['posts'][0].has_key?('links')
  end

  def test_malformed_fields_not_array
    get :index, {ids: [1,2], fields: {posts: :author}}
    assert_response :bad_request
    assert_match /Sorry - post_ids is not allowed./, response.body
  end

  def test_bad_filter
    get :index, {post_ids: [1,2], fields: :posts}
    assert_response :bad_request
    assert_match //, response.body
  end


  def test_malformed_fields_not_hash
    get :index, {ids: [1,2], fields: :posts}
    assert_response :bad_request
    assert_match /Sorry - 'fields' must contain a hash./, response.body
  end

  def test_field_not_supported
    get :index, {ids: [1,2], fields: {posts: [:id, :title, :rank, :author]}}
    assert_response :bad_request
    assert_match /Sorry - rank is not a valid field for posts./, response.body
  end

  def test_resource_not_supported
    get :index, {ids: [1,2], fields: {posters: [:id, :title]}}
    assert_response :bad_request
    assert_match /Sorry - posters is not a valid resource./, response.body
  end

  def test_index_filter_on_association
    get :index, {author: 1}
    assert_response :success
    assert_equal 1, json_response['posts'].size
  end

  # ToDo: test validating the parameter values
  # def test_index_invalid_filter_value
  #   get :index, {ids: [1,'asdfg1']}
  #   assert_response :bad_request
  # end

  def test_create_simple
    post :create, { posts: {
                      title: 'JAR is Great',
                      body:  'JSON API Resources is the greatest thing since unsliced bread.',
                      links: {
                        author: 3
                      }
                    }
                  }

    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'JAR is Great', json_response['posts'][0]['title']
    assert_equal 'JSON API Resources is the greatest thing since unsliced bread.', json_response['posts'][0]['body']
  end

  def test_create_simple_unpermitted_attributes
    post :create, { posts: {
        subject: 'JAR is Great',
        body:  'JSON API Resources is the greatest thing since unsliced bread.',
        links: {
            author: 3
        }
      }
    }

    assert_response 400
    assert_match /subject/, json_response['error']
  end

  def test_create_with_linked
    post :create, { posts: {
                      title: 'JAR is Great',
                      body:  'JSON API Resources is the greatest thing since unsliced bread.',
                      links: {
                        author: 3,
                        tags: [1,2]
                      }
                    }
                  }

    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'JAR is Great', json_response['posts'][0]['title']
    assert_equal 'JSON API Resources is the greatest thing since unsliced bread.', json_response['posts'][0]['body']
    assert_equal [1,2], json_response['posts'][0]['links']['tags']
  end

  def test_update_with_linked
    post :update, {id: 3, posts: {
        title: 'A great new Post',
        links: {
            tags: [3,4]
        }
      }
    }

    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'A great new Post', json_response['posts'][0]['title']
    assert_equal 'AAAA', json_response['posts'][0]['body']
    assert_equal [3,4], json_response['posts'][0]['links']['tags']
  end

  def test_update_unpermitted_attributes
    post :update, {id: 3, posts: {
        subject: 'A great new Post',
        links: {
            author: 1,
            tags: [3,4]
        }
      }
    }

    assert_response 400
    assert_match /author/, json_response['error']
    assert_match /subject/, json_response['error']
  end

  def test_update_bad_attributes
    post :update, {id: 3, posts: {
        subject: 'A great new Post',
        linked_objects: {
            author: 1,
            tags: [3,4]
        }
    }
    }

    assert_response 400
  end


  def test_update_patch
    put :update, {id: 3, posts: {
        title: 'A great new Post',
        links: {
            tags: [3,4]
        }
    }
    }

    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'A great new Post', json_response['posts'][0]['title']
    assert_equal 'AAAA', json_response['posts'][0]['body']
    assert_equal [3,4], json_response['posts'][0]['links']['tags']
  end

end
