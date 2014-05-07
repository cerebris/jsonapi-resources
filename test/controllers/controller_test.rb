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
    assert_match /Sorry - not a valid value for posts./, response.body
  end

  def test_malformed_fields_not_hash
    get :index, {ids: [1,2], fields: :posts}
    assert_response :bad_request
    assert_match /Sorry - not a valid value for fields./, response.body
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

end
