require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class ArticleResource < JSONAPI::Resource
  model_name 'Post'

  def self.records(options)
    options[:context].posts
  end
end

class CatResource < JSONAPI::Resource
  attribute :id
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

class JSONAPI::Resource::BeforeSaveError < StandardError; end

class ResourceTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal(PostResource._model_name, 'Post')
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_assosications
    associations = CatResource._associations
    assert_kind_of(Hash, associations)
    assert_equal(associations.size, 2)
  end

  def test_find_with_customized_base_records
    author = Person.find(1)
    posts = ArticleResource.find([], context: author).map(&:model)

    assert(posts.include?(Post.find(1)))
    refute(posts.include?(Post.find(3)))
  end

  def test_find_by_key_with_customized_base_records
    author = Person.find(1)

    post = ArticleResource.find_by_key(1, context: author).model
    assert_equal(post, Post.find(1))

    assert_raises JSONAPI::Exceptions::RecordNotFound do
      ArticleResource.find_by_key(3, context: author).model
    end
  end

  def test_find_by_keys_with_customized_base_records
    author = Person.find(1)

    posts = ArticleResource.find_by_keys([1, 2], context: author)
    assert_equal(posts.length, 2)

    assert_raises JSONAPI::Exceptions::RecordNotFound do
      ArticleResource.find_by_keys([1, 3], context: author).model
    end
  end

  def test_save_with_before_save_exception
    author = Person.new
    resource = PersonResource.new(author)
    resource.define_singleton_method :before_save do |context|
      raise JSONAPI::Resource::BeforeSaveError
    end
    assert_raises JSONAPI::Resource::BeforeSaveError do
      resource.save
    end
  end

  def test_remove_with_before_save_exception
    author = Person.new
    resource = PersonResource.new(author)
    resource.define_singleton_method :before_save do |context|
      raise JSONAPI::Resource::BeforeSaveError
    end
    assert_raises JSONAPI::Resource::BeforeSaveError do
      resource.remove
    end
  end

  def test_save
    author = Person.find(1)
    resource = PersonResource.new(author)
    assert_equal(resource.save, true)
  end
end
