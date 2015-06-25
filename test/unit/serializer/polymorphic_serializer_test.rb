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
    assert imageable.polymorphic?
  end

  def test_polymorphic_serialization
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
                  related: '/pictures/1/imageable'
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
                  related: '/pictures/2/imageable'
                },
                data: {
                  type: 'documents',
                  id: '1'
                }
              }
            }
          },
          {
            id: '3',
            type: 'pictures',
            links: {
              self: '/pictures/3'
            },
            attributes: {
              name: 'group_photo.jpg'
            },
            relationships: {
              imageable: {
                links: {
                  self: '/pictures/3/relationships/imageable',
                  related: '/pictures/3/imageable'
                },
                data: nil
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

  def test_polymorphic_get_related_resource
    get '/pictures/1/imageable'
    serialized_data = JSON.parse(response.body)
      assert_hash_equals(
      {
        data: {
          id: '1',
          type: 'products',
          links: {
            self: 'http://www.example.com/products/1'
          },
          attributes: {
            name: 'Enterprise Gizmo'
          },
          relationships: {
            picture: {
              links: {
                self: 'http://www.example.com/products/1/relationships/picture',
                related: 'http://www.example.com/products/1/picture'
              },
              data: {
                type: 'pictures',
                id: '1'
              }
            }
          }
        }
      },
      serialized_data
    )
  end

  def test_create_resource_with_polymorphic_relationship
    document = Document.find(1)
    post "/pictures/",
      {
        data: {
          type: "pictures",
          attributes: {
            name: "hello.jpg"
          },
          relationships: {
            imageable: {
              data: {
                type: "documents",
                id: document.id.to_s
              }
            }
          }
        }
      }.to_json,
      {
        'Content-Type' => JSONAPI::MEDIA_TYPE
      }
    assert_equal response.status, 201
    picture = Picture.find(json_response["data"]["id"])
    assert_not_nil picture.imageable, "imageable should be present"
  ensure
    picture.destroy
  end

  def test_polymorphic_create_relationship
    picture = Picture.find(3)
    original_imageable = picture.imageable
    assert_nil original_imageable

    patch "/pictures/#{picture.id}/relationships/imageable",
          {
            association: 'imageable',
            data: {
              type: 'documents',
              id: '1'
            }
          }.to_json,
          {
            'Content-Type' => JSONAPI::MEDIA_TYPE
          }
    assert_response :no_content
    picture = Picture.find(3)
    assert_equal 'Document', picture.imageable.class.to_s

    # restore data
    picture.imageable = original_imageable
    picture.save
  end

  def test_polymorphic_update_relationship
    picture = Picture.find(1)
    original_imageable = picture.imageable
    assert_not_equal 'Document', picture.imageable.class.to_s

    patch "/pictures/#{picture.id}/relationships/imageable",
          {
            association: 'imageable',
            data: {
              type: 'documents',
              id: '1'
            }
          }.to_json,
          {
            'Content-Type' => JSONAPI::MEDIA_TYPE
          }
    assert_response :no_content
    picture = Picture.find(1)
    assert_equal 'Document', picture.imageable.class.to_s

    # restore data
    picture.imageable = original_imageable
    picture.save
  end

  def test_polymorphic_delete_relationship
    picture = Picture.find(1)
    original_imageable = picture.imageable
    assert original_imageable

    delete "/pictures/#{picture.id}/relationships/imageable",
           {
             association: 'imageable'
           }.to_json,
           {
             'Content-Type' => JSONAPI::MEDIA_TYPE
           }
    assert_response :no_content
    picture = Picture.find(1)
    assert_nil picture.imageable

    # restore data
    picture.imageable = original_imageable
    picture.save
  end
end
