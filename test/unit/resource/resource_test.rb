require File.expand_path('../../../test_helper', __FILE__)

class ArticleResource < JSONAPI::Resource
  model_name 'Post'

  def self.records(options)
    options[:context].posts
  end
end

class NoMatchResource < JSONAPI::Resource
end

class NoMatchAbstractResource < JSONAPI::Resource
  abstract
end

class CatResource < JSONAPI::Resource
  attribute :id
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

class PersonWithCustomRecordsForResource < PersonResource
  def records_for(relationship_name, context)
    :records_for
  end
end

class PersonWithCustomRecordsForRelationshipsResource < PersonResource
  def records_for_posts(options = {})
    :records_for_posts
  end
  def record_for_preferences(options = {})
    :record_for_preferences
  end
end

class PersonWithCustomRecordsForErrorResource < PersonResource
  class AuthorizationError < StandardError; end
  def records_for(relationship_name, context)
    raise AuthorizationError
  end
end

module MyModule
  class MyNamespacedResource < JSONAPI::Resource
  end
end

class ResourceTest < ActiveSupport::TestCase
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal(PostResource._model_name, 'Post')
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_module_path
    assert_equal(MyModule::MyNamespacedResource.module_path, 'my_module/')
  end

  def test_base_resource_abstract
    assert BaseResource._abstract
  end

  def test_derived_not_abstract
    assert PersonResource < BaseResource
    refute PersonResource._abstract
  end

  def test_nil_model_class
    # ToDo:Figure out why this test does not work on Rails 4.0
    if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR >= 1
      assert_output nil, "[MODEL NOT FOUND] Model could not be found for NoMatchResource. If this a base Resource declare it as abstract.\n" do
        assert_nil NoMatchResource._model_class
      end
    end
  end

  def test_nil_abstract_model_class
    assert_output nil, '' do
      assert_nil NoMatchAbstractResource._model_class
    end
  end

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_relationships
    relationships = CatResource._relationships
    assert_kind_of(Hash, relationships)
    assert_equal(relationships.size, 2)
  end

  def test_find_with_customized_base_records
    author = Person.find(1)
    posts = ArticleResource.find([], context: author).map(&:model)

    assert(posts.include?(Post.find(1)))
    refute(posts.include?(Post.find(3)))
  end

  def test_records_for
    author = Person.find(1)
    preferences = Preferences.first
    refute(preferences == nil)
    author.update! preferences: preferences
    author_resource = PersonResource.new(author)
    assert_equal(author_resource.preferences.model, preferences)

    author_resource = PersonWithCustomRecordsForResource.new(author)
    assert_equal(author_resource.preferences.model, :records_for)

    author_resource = PersonWithCustomRecordsForErrorResource.new(author)
    assert_raises PersonWithCustomRecordsForErrorResource::AuthorizationError do
      author_resource.posts
    end
  end

  def test_records_for_meta_method_for_to_one
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author)
    assert_equal(author_resource.record_for_preferences, :record_for_preferences)
  end

  def test_records_for_meta_method_for_to_one_calling_records_for
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForResource.new(author)
    assert_equal(author_resource.record_for_preferences, :records_for)
  end

  def test_associated_records_meta_method_for_to_many
    author = Person.find(1)
    author.posts << Post.find(1)
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author)
    assert_equal(author_resource.records_for_posts, :records_for_posts)
  end

  def test_associated_records_meta_method_for_to_many_calling_records_for
    author = Person.find(1)
    author.posts << Post.find(1)
    author_resource = PersonWithCustomRecordsForResource.new(author)
    assert_equal(author_resource.records_for_posts, :records_for)
  end

  def test_find_by_key_with_customized_base_records
    author = Person.find(1)

    post = ArticleResource.find_by_key(1, context: author).model
    assert_equal(post, Post.find(1))

    assert_raises JSONAPI::Exceptions::RecordNotFound do
      ArticleResource.find_by_key(3, context: author).model
    end
  end

  def test_updatable_fields_does_not_include_id
    assert(!CatResource.updatable_fields.include?(:id))
  end

  # TODO: Please remove after `updateable_fields` is removed
  def test_updateable_fields_delegates_to_updatable_fields_with_deprecation
    ActiveSupport::Deprecation.silence do
      assert_empty(CatResource.updateable_fields(nil) - [:mother, :father, :name, :breed])
    end
  end

  # TODO: Please remove after `createable_fields` is removed
  def test_createable_fields_delegates_to_creatable_fields_with_deprecation
    ActiveSupport::Deprecation.silence do
      assert_empty(CatResource.createable_fields(nil) - [:mother, :father, :name, :breed, :id])
    end
  end

  def test_to_many_relationship_filters
    post_resource = PostResource.new(Post.find(1))
    comments = post_resource.comments
    assert_equal(2, comments.size)

    # define apply_filters method on post resource to not respect filters
    PostResource.instance_eval do
      def apply_filters(records, filters, options)
        # :nocov:
        records
        # :nocov:
      end
    end

    filtered_comments = post_resource.comments({ filters: { body: 'i liked it' } })
    assert_equal(1, filtered_comments.size)

  ensure
    # reset method to original implementation
    PostResource.instance_eval do
      def apply_filters(records, filters, options)
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_to_many_relationship_sorts
    post_resource = PostResource.new(Post.find(1))
    comment_ids = post_resource.comments.map{|c| c.model.id }
    assert_equal [1,2], comment_ids

    # define apply_filters method on post resource to not respect filters
    PostResource.instance_eval do
      def apply_sort(records, criteria)
        # :nocov:
        records
        # :nocov:
      end
    end

    sorted_comment_ids = post_resource.comments(sort_criteria: [{ field: 'id', direction: :desc}]).map{|c| c.model.id }
    assert_equal [2,1], sorted_comment_ids

  ensure
    # reset method to original implementation
    PostResource.instance_eval do
      def apply_sort(records, criteria)
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_to_many_relationship_pagination
    post_resource = PostResource.new(Post.find(1))
    comments = post_resource.comments
    assert_equal 2, comments.size

    # define apply_filters method on post resource to not respect filters
    PostResource.instance_eval do
      def apply_pagination(records, criteria, order_options)
        # :nocov:
        records
        # :nocov:
      end
    end

    paginator_class = Class.new(JSONAPI::Paginator) do
      def initialize(params)
        # param parsing and validation here
        @page = params.to_i
      end

      def apply(relation, order_options)
        relation.offset(@page).limit(1)
      end
    end

    paged_comments = post_resource.comments(paginator: paginator_class.new(1))
    assert_equal 1, paged_comments.size

  ensure
    # reset method to original implementation
    PostResource.instance_eval do
      def apply_pagination(records, criteria, order_options)
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_key_type_integer
    CatResource.instance_eval do
      key_type :integer
    end

    assert CatResource.verify_key('45')
    assert CatResource.verify_key(45)

    assert_raises JSONAPI::Exceptions::InvalidFieldValue do
      CatResource.verify_key('45,345')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_string
    CatResource.instance_eval do
      key_type :string
    end

    assert CatResource.verify_key('45')
    assert CatResource.verify_key(45)

    assert_raises JSONAPI::Exceptions::InvalidFieldValue do
      CatResource.verify_key('45,345')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_uuid
    CatResource.instance_eval do
      key_type :uuid
    end

    assert CatResource.verify_key('f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5')

    assert_raises JSONAPI::Exceptions::InvalidFieldValue do
      CatResource.verify_key('f1a-e77a-4d0a-acbb-ee0b98b3f6b5')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end

  def test_key_type_proc
    CatResource.instance_eval do
      key_type -> (key, context) {
        return key if key.nil?
        if key.to_s.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
          key
        else
          raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
        end
      }
    end

    assert CatResource.verify_key('f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5')

    assert_raises JSONAPI::Exceptions::InvalidFieldValue do
      CatResource.verify_key('f1a-e77a-4d0a-acbb-ee0b98b3f6b5')
    end

  ensure
    CatResource.instance_eval do
      key_type nil
    end
  end
end
