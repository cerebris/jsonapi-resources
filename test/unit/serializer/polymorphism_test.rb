require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'
require 'json'

class PolymorphismTest < ActionDispatch::IntegrationTest
  def setup
    @pictures = Picture.all

    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :camelized_route
  end

  def after_teardown
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def test_polymorphic_association
    associations = PictureResource._associations
    imageable = associations[:imageable]

    assert_equal associations.size, 1
    assert imageable.polymorphic
  end

  def test_polymorphism
    serialized_data = JSONAPI::ResourceSerializer.new(
      PictureResource,
      include: %w(imageable)
    ).serialize_to_hash(@pictures.map { |p| PictureResource.new p })

    assert_hash_equals(
      {
        data: [
          {
            id: '1',
            type: 'pictures',
            links: {
              self: '/pictures/1'
            },
            attributes: {
              name: 'enterprise_gizmo.jpg'
            },
            relationships: {
              imageable: {
                links: {
                  self: '/pictures/1/relationships/imageable',
                  related: nil
                },
                data: {
                  type: 'products',
                  id: '1'
                }
              }
            }
          },
          {
            id: '2',
            type: 'pictures',
            links: {
              self: '/pictures/2'
            },
            attributes: {
              name: 'company_brochure.jpg'
            },
            relationships: {
              imageable: {
                links: {
                  self: '/pictures/2/relationships/imageable',
                  related: nil
                },
                data: {
                  type: 'documents',
                  id: '1'
                }
              }
            }
          }
        ],
        :included => [
          {
            id: '1',
            type: 'products',
            links: {
              self: '/products/1'
            },
            attributes: {
              name: 'Enterprise Gizmo'
            },
            relationships: {
              picture: {
                links: {
                  self: '/products/1/relationships/picture',
                  related: '/products/1/picture',
                },
                data: {
                  type: 'pictures',
                  id: '1'
                }
              }
            }
          },
          {
            id: '1',
            type: 'documents',
            links: {
              self: '/documents/1'
            },
            attributes: {
              name: 'Company Brochure'
            },
            relationships: {
              pictures: {
                links: {
                  self: '/documents/1/relationships/pictures',
                  related: '/documents/1/pictures'
                }
              }
            }
          }
        ]
      },
      serialized_data
    )
  end
end
