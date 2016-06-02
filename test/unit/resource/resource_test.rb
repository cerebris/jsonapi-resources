require File.expand_path('../../../test_helper', __FILE__)

class ArticleResource < JSONAPI::Resource
  model_name 'Post'

  def self.records(options)
    options[:context].posts
  end
end

class PostWithBadAfterSave < ActiveRecord::Base
  self.table_name = 'posts'
  after_save :do_some_after_save_stuff

  def do_some_after_save_stuff
    errors[:base] << 'Boom! Error added in after_save callback.'
    raise ActiveRecord::RecordInvalid.new(self)
  end
end

class PostWithCustomValidationContext < ActiveRecord::Base
  self.table_name = 'posts'
  validate :api_specific_check, on: :json_api_create

  def api_specific_check
    errors[:base] << 'Record is invalid'
  end
end

class ArticleWithBadAfterSaveResource < JSONAPI::Resource
  model_name 'PostWithBadAfterSave'
  attribute :title
end

class ArticleWithCustomValidationContextResource < JSONAPI::Resource
  model_name 'PostWithCustomValidationContext'
  attribute :title
  def _save
    super(:json_api_create)
  end
end

class NoMatchResource < JSONAPI::Resource
end

class NoMatchAbstractResource < JSONAPI::Resource
  abstract
end

class CatResource < JSONAPI::Resource
  attribute :name
  attribute :breed
  attribute :kind, :delegate => :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

class PersonWithCustomRecordsForResource < PersonResource
  def records_for(relationship_name)
    :records_for
  end
end

class PersonWithCustomRecordsForRelationshipsResource < PersonResource
  def records_for_posts
    :records_for_posts
  end

  def record_for_preferences
    :record_for_preferences
  end
end

class PersonWithCustomRecordsForErrorResource < PersonResource
  class AuthorizationError < StandardError; end
  def records_for(relationship_name)
    raise AuthorizationError
  end
end

module MyModule
  class MyNamespacedResource < JSONAPI::Resource
    model_name "Person"
    has_many :related
  end

  class RelatedResource < JSONAPI::Resource
    model_name "Comment"
  end
end

module MyAPI
  class MyNamespacedResource < MyModule::MyNamespacedResource
  end

  class RelatedResource < MyModule::RelatedResource
  end
end

class ResourceTest < ActiveSupport::TestCase
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal("Post", PostResource._model_name)
  end

  def test_model_name_of_subclassed_non_abstract_resource
    assert_equal("Firm", FirmResource._model_name)
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_module_path
    assert_equal(MyModule::MyNamespacedResource.module_path, 'my_module/')
  end

  def test_resource_for_root_resource
    assert_raises NameError do
      JSONAPI::Resource.resource_for('related')
    end
  end

  def test_resource_for_with_namespaced_paths
    assert_equal(JSONAPI::Resource.resource_for('my_module/related'), MyModule::RelatedResource)
    assert_equal(PostResource.resource_for('my_module/related'), MyModule::RelatedResource)
    assert_equal(MyModule::MyNamespacedResource.resource_for('my_module/related'), MyModule::RelatedResource)
  end

  def test_resource_for_resource_does_not_exist_at_root
    assert_raises NameError do
      ArticleResource.resource_for('related')
    end
    assert_raises NameError do
      JSONAPI::Resource.resource_for('related')
    end
  end

  def test_resource_for_namespaced_resource
    assert_equal(MyModule::MyNamespacedResource.resource_for('related'), MyModule::RelatedResource)
  end

  def test_relationship_parent_point_to_correct_resource
    assert_equal MyModule::MyNamespacedResource, MyModule::MyNamespacedResource._relationships[:related].parent_resource
  end

  def test_relationship_parent_option_point_to_correct_resource
    assert_equal MyModule::MyNamespacedResource, MyModule::MyNamespacedResource._relationships[:related].options[:parent_resource]
  end

  def test_derived_resources_relationships_parent_point_to_correct_resource
    assert_equal MyAPI::MyNamespacedResource, MyAPI::MyNamespacedResource._relationships[:related].parent_resource
  end

  def test_derived_resources_relationships_parent_options_point_to_correct_resource
    assert_equal MyAPI::MyNamespacedResource, MyAPI::MyNamespacedResource._relationships[:related].options[:parent_resource]
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
    # :nocov:
    if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR >= 1
      assert_output nil, "[MODEL NOT FOUND] Model could not be found for NoMatchResource. If this a base Resource declare it as abstract.\n" do
        assert_nil NoMatchResource._model_class
      end
    end
    # :nocov:
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
    assert_equal(attrs.keys.size, 4)
  end

  def test_class_relationships
    relationships = CatResource._relationships
    assert_kind_of(Hash, relationships)
    assert_equal(relationships.size, 2)
  end

  def test_find_with_customized_base_records
    author = Person.find(1)
    posts = ArticleResource.find([], context: author).map(&:_model)

    assert(posts.include?(Post.find(1)))
    refute(posts.include?(Post.find(3)))
  end

  def test_records_for
    author = Person.find(1)
    preferences = Preferences.first
    refute(preferences == nil)
    author.update! preferences: preferences
    author_resource = PersonResource.new(author, nil)
    assert_equal(author_resource.preferences._model, preferences)

    author_resource = PersonWithCustomRecordsForResource.new(author, nil)
    assert_equal(author_resource.preferences._model, :records_for)

    author_resource = PersonWithCustomRecordsForErrorResource.new(author, nil)
    assert_raises PersonWithCustomRecordsForErrorResource::AuthorizationError do
      author_resource.posts
    end
  end

  def test_records_for_meta_method_for_to_one
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author, nil)
    assert_equal(author_resource.record_for_preferences, :record_for_preferences)
  end

  def test_records_for_meta_method_for_to_one_calling_records_for
    author = Person.find(1)
    author.update! preferences: Preferences.first
    author_resource = PersonWithCustomRecordsForResource.new(author, nil)
    assert_equal(author_resource.record_for_preferences, :records_for)
  end

  def test_associated_records_meta_method_for_to_many
    author = Person.find(1)
    author.posts << Post.find(1)
    author_resource = PersonWithCustomRecordsForRelationshipsResource.new(author, nil)
    assert_equal(author_resource.records_for_posts, :records_for_posts)
  end

  def test_associated_records_meta_method_for_to_many_calling_records_for
    author = Person.find(1)
    author.posts << Post.find(1)
    author_resource = PersonWithCustomRecordsForResource.new(author, nil)
    assert_equal(author_resource.records_for_posts, :records_for)
  end

  def test_find_by_key_with_customized_base_records
    author = Person.find(1)

    post = ArticleResource.find_by_key(1, context: author)._model
    assert_equal(post, Post.find(1))

    assert_raises JSONAPI::Exceptions::RecordNotFound do
      ArticleResource.find_by_key(3, context: author)._model
    end
  end

  def test_updatable_fields_does_not_include_id
    assert(!CatResource.updatable_fields.include?(:id))
  end

  # TODO: Please remove after `updateable_fields` is removed
  def test_updateable_fields_delegates_to_updatable_fields_with_deprecation
    ActiveSupport::Deprecation.silence do
      assert_empty(CatResource.updateable_fields(nil) - [:mother, :father, :name, :breed, :kind])
    end
  end

  # TODO: Please remove after `createable_fields` is removed
  def test_createable_fields_delegates_to_creatable_fields_with_deprecation
    ActiveSupport::Deprecation.silence do
      assert_empty(CatResource.createable_fields(nil) - [:mother, :father, :name, :breed, :id, :kind])
    end
  end

  def test_filter_on_to_many_relationship_id
    posts = PostResource.find(:comments => 3)
    assert_equal([2], posts.map(&:id))
  end

  def test_filter_on_aliased_to_many_relationship_id
    # Comment 2 is approved
    books = Api::V2::BookResource.find(:aliased_comments => 2)
    assert_equal([0], books.map(&:id))

    # However, comment 3 is non-approved, so it won't be accessible through this relationship
    books = Api::V2::BookResource.find(:aliased_comments => 3)
    assert_equal([], books.map(&:id))
  end

  def test_filter_on_has_one_relationship_id
    people = PreferencesResource.find(:author => 1)
    assert_equal([1], people.map(&:id))
  end

  def test_to_many_relationship_filters
    post_resource = PostResource.new(Post.find(1), nil)
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
    post_resource = PostResource.new(Post.find(1), nil)
    comment_ids = post_resource.comments.map{|c| c._model.id }
    assert_equal [1,2], comment_ids

    # define apply_filters method on post resource to not respect filters
    PostResource.instance_eval do
      def apply_sort(records, criteria, context = {})
        # :nocov:
        records
        # :nocov:
      end
    end

    sorted_comment_ids = post_resource.comments(sort_criteria: [{ field: 'id', direction: :desc}]).map{|c| c._model.id }
    assert_equal [2,1], sorted_comment_ids

  ensure
    # reset method to original implementation
    PostResource.instance_eval do
      def apply_sort(records, criteria, context = {})
        # :nocov:
        super
        # :nocov:
      end
    end
  end

  def test_lookup_association_chain
    model_names = %w(person posts parent_post)
    result = PostResource._lookup_association_chain(model_names)
    assert_equal 2, result.length

    posts_reflection, parent_post_reflection = result
    assert_equal :posts, posts_reflection.name
    assert_equal :parent_post, parent_post_reflection.name

    assert_equal "posts", posts_reflection.table_name
    assert_equal "posts", parent_post_reflection.table_name

    assert_equal "author_id", posts_reflection.foreign_key
    assert_equal "parent_post_id", parent_post_reflection.foreign_key
  end

  def test_build_joins
    model_names = %w(person posts parent_post author)
    associations = PostResource._lookup_association_chain(model_names)
    result = PostResource._build_joins(associations)

    assert_equal "LEFT JOIN posts AS parent_post_sorting ON parent_post_sorting.id = posts.parent_post_id
LEFT JOIN people AS author_sorting ON author_sorting.id = posts.author_id", result
  end

  def test_to_many_relationship_pagination
    post_resource = PostResource.new(Post.find(1), nil)
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

  def test_id_attr_deprecation
    _out, err = capture_io do
      eval <<-CODE
        class ProblemResource < JSONAPI::Resource
          attribute :id
        end
      CODE
    end
    assert_match /DEPRECATION WARNING: Id without format is no longer supported. Please remove ids from attributes, or specify a format./, err
  end

  def test_id_attr_with_format
    _out, err = capture_io do
      eval <<-CODE
        class NotProblemResource < JSONAPI::Resource
          attribute :id, format: :string
        end
      CODE
    end
    assert_equal "", err
  end

  def test_links_resource_warning
    _out, err = capture_io do
      eval "class LinksResource < JSONAPI::Resource; end"
    end
    assert_match /LinksResource` is a reserved resource name/, err
  end

  def test_reserved_key_warnings
    _out, err = capture_io do
      eval <<-CODE
        class BadlyNamedAttributesResource < JSONAPI::Resource
          attributes :type
        end
      CODE
    end
    assert_match /`type` is a reserved key in ./, err
  end

  def test_reserved_relationship_warnings
    %w(id type).each do |key|
      _out, err = capture_io do
        eval <<-CODE
          class BadlyNamedAttributesResource < JSONAPI::Resource
            has_one :#{key}
          end
        CODE
      end
      assert_match /`#{key}` is a reserved relationship name in ./, err
    end
    %w(types ids).each do |key|
      _out, err = capture_io do
        eval <<-CODE
          class BadlyNamedAttributesResource < JSONAPI::Resource
            has_many :#{key}
          end
        CODE
      end
      assert_match /`#{key}` is a reserved relationship name in ./, err
    end
  end

  def test_abstract_warning
    _out, err = capture_io do
      eval <<-CODE
        class NoModelResource < JSONAPI::Resource
        end
        NoModelResource._model_class
      CODE
    end
    assert_match "[MODEL NOT FOUND] Model could not be found for ResourceTest::NoModelResource. If this a base Resource declare it as abstract.\n", err
  end

  def test_no_warning_when_abstract
    _out, err = capture_io do
      eval <<-CODE
        class NoModelAbstractResource < JSONAPI::Resource
          abstract
        end
        NoModelAbstractResource._model_class
      CODE
    end
    assert_match "", err
  end

  def test_correct_error_surfaced_if_validation_errors_in_after_save_callback
    post = PostWithBadAfterSave.find(1)
    post_resource = ArticleWithBadAfterSaveResource.new(post, nil)
    err = assert_raises JSONAPI::Exceptions::ValidationErrors do
      post_resource.replace_fields({:attributes => {:title => 'Some title'}})
    end
    assert_equal(err.error_messages[:base], ['Boom! Error added in after_save callback.'])
  end

  def test_resource_for_model_use_hint
    special_person = Person.create!(name: 'Special', date_joined: Date.today, special: true)
    special_resource = SpecialPersonResource.new(special_person, nil)
    resource_model = SpecialPersonResource.records({}).first # simulate a find
    assert_equal(SpecialPersonResource, SpecialPersonResource.resource_for_model(resource_model))
  end

  def test_resource_performs_validations_in_custom_context
    post = PostWithCustomValidationContext.find(1)
    post_resource = ArticleWithCustomValidationContextResource.new(post, nil)
    err = assert_raises JSONAPI::Exceptions::ValidationErrors do
      post_resource._save
    end
    assert_equal(err.error_messages[:base], ['Record is invalid'])
  end

  def test_resources_for_transforms_records_into_resources
    resources = PostResource.resources_for([Post.first], {})
    assert_equal(PostResource, resources.first.class)
  end
end
