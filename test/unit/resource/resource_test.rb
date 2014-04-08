require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class ArticleResource < JSON::API::Resource
  set_serializer_name 'PostSerializer'
  set_model_name 'Post'
end

class CatResource < JSON::API::Resource
  attribute :id
  attribute :name
  attribute :breed
end



class ResourceTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
    @kitty_resource = CatResource.new
  end

  def test_model_name
    assert_equal(PostResource.model_name, 'Post')
  end

  def test_serializer_name
    assert_equal(PostResource.serializer_name, 'PostSerializer')
  end

  def test_model
    assert_equal(PostResource.model_class, Post)
  end

  def test_serializer
    assert_equal(PostResource.serializer_class, PostSerializer)
  end

  def test_model_alternate
    assert_equal(ArticleResource.model_class, Post)
  end

  def test_serializer_alternate
    assert_equal(ArticleResource.serializer_class, PostSerializer)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Array, attrs)
    assert_equal(attrs.size, 3)
  end
end
