require File.expand_path('../../../test_helper', __FILE__)

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

class PersonWithCustomRecordsForResource < PersonResource
  def records_for(association_name, context)
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
  def records_for(association_name, context)
    raise AuthorizationError
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

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_associations
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

  def test_records_for_meta_method_for_has_one
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author)
    assert_equal(author_resource.record_for_preferences, :record_for_preferences)
  end

  def test_records_for_meta_method_for_has_one_calling_records_for
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForResource.new(author)
    assert_equal(author_resource.record_for_preferences, :records_for)
  end

  def test_associated_records_meta_method_for_has_many
    author = Person.find(1)
    author.posts << Post.find(1)
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author)
    assert_equal(author_resource.records_for_posts, :records_for_posts)
  end

  def test_associated_records_meta_method_for_has_many_calling_records_for
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

  def test_has_many_association_filters
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

    # reset method to original implementation
    PostResource.instance_eval do
      def apply_filters(records, filters, options)
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_has_many_association_sorts
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

    sorted_comment_ids = post_resource.comments(sort_criteria: [{ field: 'id', direction: 'desc'}]).map{|c| c.model.id }
    assert_equal [2,1], sorted_comment_ids

    # reset method to original implementation
    PostResource.instance_eval do
      def apply_sort(records, criteria)
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_has_many_association_pagination
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

    # reset method to original implementation
    PostResource.instance_eval do
      def apply_pagination(records, criteria, order_options)
        # :nocov:
        super
        # :nocov:
      end
    end
  end
end
