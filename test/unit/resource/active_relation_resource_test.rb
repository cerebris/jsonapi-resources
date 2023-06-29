require File.expand_path('../../../test_helper', __FILE__)

class ArPostResource < JSONAPI::Resource
  resource_retrieval_strategy 'JSONAPI::ActiveRelationRetrievalV10'

  model_name 'Post'
  attribute :headline, delegate: :title
  has_one :author
  has_many :tags, primary_key: :tags_import_id, inverse_relationship: :things
end

class ActiveRelationResourceTest < ActiveSupport::TestCase
  def setup
    skip("Skipping: Currently test is only valid for ActiveRelationRetrievalV10")
  end

  def test_find_fragments_no_attributes
    filters = {}
    posts_identities = ArPostResource.find_fragments(filters)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ArPostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ArPostResource, 1), posts_identities.values[0].identity
    assert posts_identities.values[0].is_a?(JSONAPI::ResourceFragment)
  end

  def test_find_fragments_cache_field
    filters = {}
    options = { cache: true }
    posts_identities = ArPostResource.find_fragments(filters, options)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ArPostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ArPostResource, 1), posts_identities.values[0].identity
    assert posts_identities.values[0].is_a?(JSONAPI::ResourceFragment)
    assert posts_identities.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_one_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(ArPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 20)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = ArPostResource._relationship('author')
    related_fragments = ArPostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 2, related_fragments.values[0].related_from.length
  end

  def test_find_related_has_one_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(ArPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 20)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = ArPostResource._relationship('author')
    related_fragments = ArPostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 2, related_fragments.values[0].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_many_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(ArPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 12),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 14)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = ArPostResource._relationship('tags')
    related_fragments = ArPostResource.send(:find_included_fragments, source_fragments, relationship, options)

    assert_equal 8, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal 2, related_fragments[JSONAPI::ResourceIdentity.new(TagResource, 502)].related_from.length
  end

  def test_find_related_has_many_fragments_pagination
    params = ActionController::Parameters.new(number: 2, size: 4)
    options = { paginator: PagedPaginator.new(params) }
    source_rids = [JSONAPI::ResourceIdentity.new(ArPostResource, 15)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = ArPostResource._relationship('tags')
    related_fragments = ArPostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 1, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 516), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 516), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
  end

  def test_find_related_has_many_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(ArPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 12),
                   JSONAPI::ResourceIdentity.new(ArPostResource, 14)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = ArPostResource._relationship('tags')
    related_fragments = ArPostResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 8, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_fragments.values[0].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal 2, related_fragments[JSONAPI::ResourceIdentity.new(TagResource, 502)].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_polymorphic_fragments
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(PictureResource, 3)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = PictureResource._relationship('imageable')
    related_fragments = PictureResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_fragments.values[0].identity
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_fragments.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_fragments.values[1].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_fragments.values[0].identity
  end

  def test_find_related_polymorphic_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(PictureResource, 3)]
    source_fragments = source_rids.collect {|rid| JSONAPI::ResourceFragment.new(rid) }

    relationship = PictureResource._relationship('imageable')
    related_fragments = PictureResource.find_included_fragments(source_fragments, relationship, options)

    assert_equal 2, related_fragments.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_fragments.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_fragments.values[0].identity
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_fragments.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_fragments.values[1].identity
    assert related_fragments.values[0].is_a?(JSONAPI::ResourceFragment)
    assert_equal 1, related_fragments.values[0].related_from.length
    assert related_fragments.values[0].cache.is_a?(ActiveSupport::TimeWithZone)
    assert related_fragments.values[1].cache.is_a?(ActiveSupport::TimeWithZone)
  end
end
