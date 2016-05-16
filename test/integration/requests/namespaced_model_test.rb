require File.expand_path('../../../test_helper', __FILE__)

class NamedspacedModelTest < ActionDispatch::IntegrationTest
  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def test_get_flat_posts
    get '/flat_posts', headers: { 'Accept' => JSONAPI::MEDIA_TYPE }
    assert_equal 200, status
    assert_equal "flat_posts", json_response["data"].first["type"]
  end
end
