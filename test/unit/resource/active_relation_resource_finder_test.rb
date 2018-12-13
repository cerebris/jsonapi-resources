require File.expand_path('../../../test_helper', __FILE__)

class ARPostResource < JSONAPI::Resource
  model_name 'Post'
  attribute :headline, delegate: :title
  has_one :author
  has_many :tags, primary_key: :tags_import_id
end

class ActiveRelationResourceFinderTest < ActiveSupport::TestCase
  def setup
  end

  def test_find_fragments_no_attributes
    filters = {}
    posts_identities = ARPostResource.find_fragments(filters)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.values[0][:identity]
    assert posts_identities.values[0].is_a?(Hash)
    assert_equal 1, posts_identities.values[0].length
  end

  def test_find_fragments_cache_field
    filters = {}
    options = { cache: true }
    posts_identities = ARPostResource.find_fragments(filters, options)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.values[0][:identity]
    assert posts_identities.values[0].is_a?(Hash)
    assert_equal 2, posts_identities.values[0].length
    assert posts_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_fragments_cache_field_attributes
    filters = {}
    options = { attributes: [:headline, :author_id], cache: true }
    posts_identities = ARPostResource.find_fragments(filters, options)

    assert_equal 20, posts_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ARPostResource, 1), posts_identities.values[0][:identity]
    assert posts_identities.values[0].is_a?(Hash)
    assert_equal 3, posts_identities.values[0].length
    assert_equal 2, posts_identities.values[0][:attributes].length
    assert posts_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
    assert_equal 'New post', posts_identities.values[0][:attributes][:headline]
    assert_equal 1001, posts_identities.values[0][:attributes][:author_id]
  end

  def test_find_related_has_one_fragments_no_attributes
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 20)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'author', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 2, related_identities.values[0].length
    assert_equal 2, related_identities.values[0][:related][:author].length
  end

  def test_find_related_has_one_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 20)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'author', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 3, related_identities.values[0].length
    assert_equal 2, related_identities.values[0][:related][:author].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_one_fragments_cache_field_attributes
    options = { cache: true, attributes: [:name] }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 20)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'author', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(AuthorResource, 1001), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 4, related_identities.values[0].length
    assert_equal 2, related_identities.values[0][:related][:author].length
    assert_equal 1, related_identities.values[0][:attributes].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
    assert_equal 'Joe Author', related_identities.values[0][:attributes][:name]
  end

  def test_find_related_has_many_fragments_no_attributes
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 12),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 14)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'tags', options)

    assert_equal 8, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 2, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:tags].length
    assert_equal 2, related_identities[JSONAPI::ResourceIdentity.new(TagResource, 502)][:related][:tags].length
  end

  def test_find_related_has_many_fragments_pagination
    params = ActionController::Parameters.new(number: 2, size: 4)
    options = { paginator: PagedPaginator.new(params) }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 15)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'tags', options)

    assert_equal 1, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 516), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 516), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 2, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:tags].length
  end

  def test_find_related_has_many_fragments_pagination_included_key
    params = ActionController::Parameters.new(number: 2, size: 4)
    options = { paginator: PagedPaginator.new(params) }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 15)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'tags', options, :tags)

    assert_equal 5, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 502), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 502), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 2, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:tags].length
  end

  def test_find_related_has_many_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 12),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 14)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'tags', options)

    assert_equal 8, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 3, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:tags].length
    assert_equal 2, related_identities[JSONAPI::ResourceIdentity.new(TagResource, 502)][:related][:tags].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_has_many_fragments_cache_field_attributes
    options = { cache: true, attributes: [:name] }
    source_rids = [JSONAPI::ResourceIdentity.new(ARPostResource, 1),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 2),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 12),
                   JSONAPI::ResourceIdentity.new(ARPostResource, 14)]

    related_identities = ARPostResource.find_related_fragments(source_rids, 'tags', options)

    assert_equal 8, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(TagResource, 501), related_identities.values[0][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 4, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:tags].length
    assert_equal 2, related_identities[JSONAPI::ResourceIdentity.new(TagResource, 502)][:related][:tags].length
    assert_equal 1, related_identities.values[0][:attributes].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
    assert_equal 'short', related_identities.values[0][:attributes][:name]
  end

  def test_find_related_polymorphic_fragments_no_attributes
    options = {}
    source_rids = [JSONAPI::ResourceIdentity.new(PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(PictureResource, 20)]

    related_identities = PictureResource.find_related_fragments(source_rids, 'imageable', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.values[0][:identity]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.values[1][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 2, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:imageable].length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.values[0][:identity]
  end

  def test_find_related_polymorphic_fragments_cache_field
    options = { cache: true }
    source_rids = [JSONAPI::ResourceIdentity.new(PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(PictureResource, 20)]

    related_identities = PictureResource.find_related_fragments(source_rids, 'imageable', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.values[0][:identity]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.values[1][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 3, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:imageable].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
  end

  def test_find_related_polymorphic_fragments_cache_field_attributes
    options = { cache: true, attributes: [:name] }
    source_rids = [JSONAPI::ResourceIdentity.new(PictureResource, 1),
                   JSONAPI::ResourceIdentity.new(PictureResource, 2),
                   JSONAPI::ResourceIdentity.new(PictureResource, 20)]

    related_identities = PictureResource.find_related_fragments(source_rids, 'imageable', options)

    assert_equal 2, related_identities.length
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.keys[0]
    assert_equal JSONAPI::ResourceIdentity.new(ProductResource, 1), related_identities.values[0][:identity]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.keys[1]
    assert_equal JSONAPI::ResourceIdentity.new(DocumentResource, 1), related_identities.values[1][:identity]
    assert related_identities.values[0].is_a?(Hash)
    assert_equal 4, related_identities.values[0].length
    assert_equal 1, related_identities.values[0][:related][:imageable].length
    assert_equal 1, related_identities.values[0][:attributes].length
    assert related_identities.values[0][:cache].is_a?(ActiveSupport::TimeWithZone)
    assert_equal 'Enterprise Gizmo', related_identities.values[0][:attributes][:name]
  end

  def test_gets_relationship_chain_with_only_field
    relationships, path, field = PictureResource.parse_relationship_path('name')
    assert_equal [], relationships
    assert_equal '', path
    assert_equal 'name', field
  end

  def test_gets_relationship_chain_with_field_polymorphic_one_level
    relationships, path, field = PictureResource.parse_relationship_path('imageable.name')
    assert_equal [PictureResource._relationship(:imageable)], relationships
    assert_equal 'imageable', path
    assert_equal 'name', field
  end

  def test_gets_relationship_chain_with_field_one_level
    relationships, path, field = PostResource.parse_relationship_path('author.name')
    assert_equal [PostResource._relationship(:author)], relationships
    assert_equal 'author', path
    assert_equal 'name', field
  end

  def test_gets_relationship_chain_with_two_relationship_levels
    relationships, path, field = PostResource.parse_relationship_path('author.comments')
    assert_equal [PostResource._relationship(:author), PersonResource._relationship(:comments)], relationships
    assert_equal 'author.comments', path
    assert_nil field
  end

  def test_gets_relationship_chain_with_two_relationship_levels_and_field
    relationships, path, field = PostResource.parse_relationship_path('author.comments.body')
    assert_equal [PostResource._relationship(:author), PersonResource._relationship(:comments)], relationships
    assert_equal 'author.comments', path
    assert_equal 'body', field
  end

  def test_gets_relationship_chain_with_three_relationship_levels_and_field
    relationships, path, field = PostResource.parse_relationship_path('author.comments.tags.name')
    assert_equal [PostResource._relationship(:author),
                  PersonResource._relationship(:comments),
                 CommentResource._relationship(:tags)], relationships
    assert_equal 'author.comments.tags', path
    assert_equal 'name', field
  end
end
