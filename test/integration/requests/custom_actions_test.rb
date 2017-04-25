require File.expand_path('../../../test_helper', __FILE__)

class CustomActionsTest < ActionDispatch::IntegrationTest
  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
    JSONAPI.configuration.route_format = :underscored_route
    Api::V2::BookResource.paginator :offset
    $test_user = Person.find(1)
  end

  def after_teardown
    JSONAPI.configuration.route_format = :underscored_route
  end

  def test_custom_action_not_resource
    http_request(path: '/api/custom_actions/posts/1/not_resource')

    assert_equal json_response, {}
    assert_equal 202, status
  end

  def test_custom_action_instance_get
    first_post = Post.first
    http_request(path: '/api/custom_actions/posts/1/favorite')

    assert_equal response_data_attributes['title'], first_post.title
    assert_equal 200, status
  end

  def test_custom_action_instance_post
    assert_difference 'Post.count', 1, 'should spawn a new Post' do
      http_request(method: :post, path: '/api/custom_actions/posts/1/draft')
    end

    assert_equal response_data_attributes['title'], 'Custom action post'
    assert_equal 200, status
  end

  def test_custom_action_instance_includes
    http_request(method: :post, path: '/api/custom_actions/posts/1/draft_with_comments') # includes: 'comments'

    assert_equal 200, status
    assert_equal [], response_includes['comments']['data']
    assert_equal 'Custom action post', response_data_attributes['title']
  end

  def test_custom_action_instance_fields
    http_request(method: :post, path: '/api/custom_actions/posts/1/draft?fields[posts]=title') # fields: 'title'

    expected_attributes = {"title" => "Custom action post"}

    assert_equal 200, status
    assert_equal expected_attributes, response_data_attributes
  end

  def test_custom_action_not_exist
    http_request(method: :post, path: '/api/custom_actions/posts/1/randomname')

    assert_equal 404, status
  end

  def test_custom_action_instance_get_nil
    http_request(path: '/api/custom_actions/posts/1/nil_response')

    assert_equal "{}", response.body
    assert_equal 202, status
  end

  def test_custom_action_instance_invalid_model_response
    http_request(path: '/api/custom_actions/posts/1/invalid_model')

    assert_equal 'Invalid field value', json_response["errors"].first['title']
    assert_equal 400, status
  end

  def test_custom_action_instance_other_resource_type_response
    http_request(path: '/api/custom_actions/posts/1/last_author')

    expected_author = Person.last

    assert_equal "people", response_type
    assert_equal expected_author.name, response_data_attributes['name']
    assert_equal 200, status
  end

  def test_custom_action_collection_get
    expected_post = Post.last
    http_request(path: '/api/custom_actions/posts/last') # collection actions doesn't require IDs

    assert_equal expected_post.title, response_data_attributes['title']
    assert_equal 200, status
  end

  def test_custom_action_instance_get_custom_method
    expected_post = Post.last
    http_request(path: '/api/custom_actions/posts/1/friend')

    assert_equal expected_post.title, response_data_attributes['title']
    assert_equal 200, status
  end

  def test_custom_action_instance_post_custom_attributes
    assert_difference 'Post.count', 1, 'should spawn a new Post' do
      data = { "data" => { "user-title" => 'Hell yeaah!' } }
      http_request(method: :put, path: '/api/custom_actions/posts/1/custom_draft', params: data)
    end

    assert_equal response_data_attributes['title'], 'Hell yeaah!'
    assert_equal 200, status
  end

  private

  def http_request(method: :get, path: '/', params: {})
    public_send(method, path, params: params.to_json, headers: default_headers)
  end

  def default_headers
    { 'CONTENT_TYPE' => 'application/vnd.api+json', 'Accept' => JSONAPI::MEDIA_TYPE }
  end

  def response_type
    json_response['data']['type']
  end

  def response_data
    json_response['data']
  end

  def response_data_attributes
    response_data['attributes']
  end

  def response_includes
    response_data['relationships']
  end
end
