require File.expand_path('../../../test_helper', __FILE__)

module V10
  class BaseResource < JSONAPI::Resource
    abstract
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'
  end

  class PostResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    model_name 'Post'
    attribute :headline, delegate: :title
    has_one :author
    has_many :tags
  end

  class AuthorResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    model_name 'Person'
    attributes :name

    has_many :posts, inverse_relationship: :author
    has_many :pictures
  end

  class TagResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    attributes :name

    has_many :posts
  end

  class PictureResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    attribute :name
    has_one :author

    has_one :imageable, polymorphic: true
    # has_one :document, exclude_linkage_data: true
    # has_one :product, exclude_linkage_data: true
  end

  class ImageableResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    polymorphic
    has_one :picture
  end

  class DocumentResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    attribute :name

    has_many :pictures, inverse_relationship: :document

    has_one :author, class_name: 'Person'
  end

  class ProductResource < V10::BaseResource
    resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

    attribute :name
    has_many :pictures, inverse_relationship: :product
    has_one :designer, class_name: 'Person'

    def picture_id
      _model.picture.id
    end
  end
end

class ActiveRelationResourceTest < ActiveSupport::TestCase
  def setup
    # skip("Skipping: Currently test is only valid for ActiveRelationRetrievalV10")
  end

  def test_find_fragments_no_attributes
    filters = {}
    posts_identities = V10::PostResource.find_fragments(filters)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::PostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::PostResource, 1), posts_identities.values[0].identity
    assert posts_identities.values[0].is_a?(JSONAPI::ResourceFragment)
  end

  def test_find_fragments_cache_field
    filters = {}
    options = { cache: true }
    posts_identities = V10::PostResource.find_fragments(filters, options)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::PostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::PostResource, 1), posts_identities.values[0].identity
    assert posts_identities.values[0].is_a?(JSONAPI::ResourceFragment)
    assert posts_identities.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_one_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PostResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 20)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PostResource._relationship('author')
    related_fragments = V10::PostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::AuthorResource, 1001), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::AuthorResource, 1001), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 2, related_fragments.values[0].related_from.length
  end

  def test_find_related_has_one_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PostResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 20)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PostResource._relationship('author')
    related_fragments = V10::PostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::AuthorResource, 1001), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::AuthorResource, 1001), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 2, related_fragments.values[0].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_many_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PostResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 12),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 14)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PostResource._relationship('tags')
    related_fragments = V10::PostResource.send(:find_included_fragments, source_fragments, relationship, options)

    assert_equal 8, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 501), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 501), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal 2, related_fragments[JSONAPI::ResourceIdentity.new(V10::TagResource, 502)].related_from.length
  end

  def test_find_related_has_many_fragments_pagination
    params = ActionController::Parameters.new(number: 2, size: 4)
    options = { paginator: PagedPaginator.new(params) }
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PostResource, 15)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PostResource._relationship('tags')
    related_fragments = V10::PostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 1, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 516), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 516), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
  end

  def test_find_related_has_many_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PostResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 12),
                   JSONAPI::ResourceIdentity.new(V10::PostResource, 14)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PostResource._relationship('tags')
    related_fragments = V10::PostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 8, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 501), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::TagResource, 501), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal 2, related_fragments[JSONAPI::ResourceIdentity.new(V10::TagResource, 502)].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_polymorphic_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 3)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PictureResource._relationship('imageable')
    related_fragments = V10::PictureResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.values[0].identity
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.values[1].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.values[0].identity
  end

  def test_find_related_polymorphic_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 3)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PictureResource._relationship('imageable')
    related_fragments = V10::PictureResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.values[0].identity
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.values[1].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
    assert related_fragments.values[1].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_polymorphic_fragments_not_cached
    options = { cache: false }
    source_rids = [JSONAPI::ResourceIdentity.new(V10::PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(V10::PictureResource, 3)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = V10::PictureResource._relationship('imageable')
    related_fragments = V10::PictureResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(V10::ProductResource, 1), related_fragments.values[0].identity
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(V10::DocumentResource, 1), related_fragments.values[1].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
  end
end
