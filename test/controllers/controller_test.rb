require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/active_record', __FILE__)

class PostsControllerTest < ActionController::TestCase

  def test_index
    get :index
    assert_response :success
  end
end
