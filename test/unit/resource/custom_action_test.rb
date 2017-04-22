require File.expand_path('../../../test_helper', __FILE__)

class PostResource < JSONAPI::Resource
  model_name 'Post'

  custom_action :nil_result

  def nil_result(data)
    nil
  end
end

class CustomActionTest < ActiveSupport::TestCase
  def setup
    @post = Post.first
  end

  def test_custom_action_callbacks
    %w(before after around).each do |callback|
      assert_equal(PostResource.respond_to?("#{callback}_nil_result_action"), true)
      assert_equal(PostResource.respond_to?("#{callback}_custom_actions"), true)
    end
  end
end
