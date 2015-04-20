require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class RequestTest < ActionDispatch::IntegrationTest

  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def after_teardown
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.route_format = :underscored_route
  end

  def test_get
    get '/posts'
    assert_equal 200, status
  end

  def test_get_nested_has_one
    get '/posts/1/author'
    assert_equal 200, status
  end

  def test_get_nested_has_many
    get '/posts/1/comments'
    assert_equal 200, status
  end

  def test_get_nested_has_many_bad_param
    get '/posts/1/comments?association=books'
    assert_equal 200, status
  end

  def test_get_underscored_key
    JSONAPI.configuration.json_key_format = :underscored_key
    get '/iso_currencies'
    assert_equal 200, status
    assert_equal 3, json_response['data'].size
  end

  def test_get_underscored_key_filtered
    JSONAPI.configuration.json_key_format = :underscored_key
    get '/iso_currencies?filter[country_name]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['country_name']
  end

  def test_get_camelized_key_filtered
    JSONAPI.configuration.json_key_format = :camelized_key
    get '/iso_currencies?filter[countryName]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['countryName']
  end

  def test_get_camelized_route_and_key_filtered
    JSONAPI.configuration.json_key_format = :camelized_key
    get '/api/v4/isoCurrencies?filter[countryName]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['countryName']
  end

  def test_get_camelized_route_and_links
    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :camelized_route
    get '/api/v4/expenseEntries/1/links/isoCurrency'
    assert_equal 200, status
    assert_hash_equals({'links' => {
                         'self' => 'http://www.example.com/api/v4/expenseEntries/1/links/isoCurrency',
                         'related' => 'http://www.example.com/api/v4/expenseEntries/1/isoCurrency'
                       },
                       'data' => {
                          'type' => 'isoCurrencies',
                          'id' => 'USD'
                         }
                       }, json_response)
  end

  def test_put_single_without_content_type
    put '/posts/3',
        {
          'data' => {
            'linkage' => {
              'type' => 'posts',
              'id' => '3',
            },
            'title' => 'A great new Post',
            'links' => {
              'tags' => [
                {type: 'tags', id: 3},
                {type: 'tags', id: 4}
              ]
            }
          }
        }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 415, status
  end

  def test_put_single
    put '/posts/3',
        {
          'data' => {
            'type' => 'posts',
            'id' => '3',
            'title' => 'A great new Post',
            'links' => {
              'tags' => {
                'linkage' => [
                  {type: 'tags', id: 3},
                  {type: 'tags', id: 4}
                ]
              }
            }
          }
        }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 200, status
  end

  def test_post_single_without_content_type
    post '/posts',
      {
        'posts' => {
          'title' => 'A great new Post',
          'links' => {
            'tags' => {
              'linkage' => [
                  {type: 'tags', id: 3},
                  {type: 'tags', id: 4}
                ]
            }
          }
        }
      }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 415, status
  end

  def test_post_single
    post '/posts',
      {
        'data' => {
          'type' => 'posts',
          'title' => 'A great new Post',
          'body' => 'JSONAPIResources is the greatest thing since unsliced bread.',
          'links' => {
            'author' => {'linkage' => {type: 'people', id: '3'}}
          }
        }
      }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  end

  def test_post_single_missing_data_contents
    post '/posts',
         {
           'data' => {
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 400, status
  end

  def test_post_single_minimal_valid
    post '/comments',
         {
           'data' => {
             'type' => 'comments'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
    assert_nil json_response['data']['body']
    assert_nil json_response['data']['links']['post']['linkage']
    assert_nil json_response['data']['links']['author']['linkage']
  end

  def test_post_single_minimal_invalid
    post '/posts',
      {
        'data' => {
          'type' => 'posts'
        }
      }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 422, status
  end

  def test_update_association_without_content_type
    ruby = Section.find_by(name: 'ruby')
    patch '/posts/3/links/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json

    assert_equal 415, status
  end

  def test_patch_update_association_has_one
    ruby = Section.find_by(name: 'ruby')
    patch '/posts/3/links/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_put_update_association_has_one
    ruby = Section.find_by(name: 'ruby')
    put '/posts/3/links/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_patch_update_association_has_many_acts_as_set
    # Comments are acts_as_set=false so PUT/PATCH should respond with 403

    rogue = Comment.find_by(body: 'Rogue Comment Here')
    patch '/posts/5/links/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 403, status
  end

  def test_post_update_association_has_many
    rogue = Comment.find_by(body: 'Rogue Comment Here')
    post '/posts/5/links/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_put_update_association_has_many_acts_as_set
    # Comments are acts_as_set=false so PUT/PATCH should respond with 403. Note: JR currently treats PUT and PATCH as equivalent

    rogue = Comment.find_by(body: 'Rogue Comment Here')
    put '/posts/5/links/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 403, status
  end

  def test_index_content_type
    get '/posts'
    assert_match JSONAPI::MEDIA_TYPE, headers['Content-Type']
  end

  def test_get_content_type
    get '/posts/3'
    assert_match JSONAPI::MEDIA_TYPE, headers['Content-Type']
  end

  def test_put_content_type
    put '/posts/3',
        {
          'data' => {
            'type' => 'posts',
            'id' => '3',
            'title' => 'A great new Post',
            'links' => {
              'tags' => {
                'linkage' => [
                  {type: 'tags', id: 3},
                  {type: 'tags', id: 4}
                ]
              }
            }
          }
        }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_match JSONAPI::MEDIA_TYPE, headers['Content-Type']
  end

  def test_patch_content_type
    patch '/posts/3',
        {
          'data' => {
            'type' => 'posts',
            'id' => '3',
            'title' => 'A great new Post',
            'links' => {
              'tags' => {
                'linkage' => [
                  {type: 'tags', id: 3},
                  {type: 'tags', id: 4}
                ]
              }
            }
          }
        }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_match JSONAPI::MEDIA_TYPE, headers['Content-Type']
  end

  def test_post_correct_content_type
    post '/posts',
      {
       'data' => {
         'type' => 'posts',
         'title' => 'A great new Post',
         'links' => {
           'author' => {'linkage' => {type: 'people', id: '3'}}
         }
       }
     }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_match JSONAPI::MEDIA_TYPE, headers['Content-Type']
  end

  def test_destroy_single
    delete '/posts/7'
    assert_equal 204, status
    assert_nil headers['Content-Type']
  end

  def test_destroy_multiple
    delete '/posts/8,9'
    assert_equal 204, status
  end

  def test_pagination_none
    Api::V2::BookResource.paginator :none
    get '/api/v2/books'
    assert_equal 200, status
    assert_equal 1000, json_response['data'].size
  end

  def test_pagination_offset_style
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books'
    assert_equal 200, status
    assert_equal JSONAPI.configuration.default_page_size, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['title']
  end

  def test_pagination_offset_style_offset
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[offset]=50'
    assert_equal 200, status
    assert_equal JSONAPI.configuration.default_page_size, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['title']
  end

  def test_pagination_offset_style_offset_limit
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[offset]=50&page[limit]=20'
    assert_equal 200, status
    assert_equal 20, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['title']
  end

  def test_pagination_offset_bad_param
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[irishsetter]=50&page[limit]=20'
    assert_equal 400, status
  end

  def test_pagination_related_resources_link
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[limit]=2'
    assert_equal 200, status
    assert_equal 2, json_response['data'].size
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments',
                 json_response['data'][1]['links']['book_comments']['related']
  end

  def test_pagination_related_resources_data
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/1/book_comments?page[limit]=10'
    assert_equal 200, status
    assert_equal 10, json_response['data'].size
    assert_equal 'This is comment 9 on book 1.', json_response['data'][9]['body']
  end

  def test_pagination_related_resources_data_includes
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/1/book_comments?page[limit]=10&include=author,book'
    assert_equal 200, status
    assert_equal 10, json_response['data'].size
    assert_equal 'This is comment 9 on book 1.', json_response['data'][9]['body']
  end

  def test_flow_self
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['links']['self']
    assert_equal 200, status
    assert_hash_equals post_1, json_response['data']
  end

  def test_flow_link_has_one_self_link
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['links']['author']['self']
    assert_equal 200, status
    assert_hash_equals(json_response, {
                                      'links' => {
                                        'self' => 'http://www.example.com/posts/1/links/author',
                                        'related' => 'http://www.example.com/posts/1/author'
                                      },
                                      'data' => {type: 'people', id: '1'}
                                    })
  end

  def test_flow_link_has_many_self_link
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['links']['tags']['self']
    assert_equal 200, status
    assert_hash_equals(json_response,
                       {
                         'links' => {
                           'self' => 'http://www.example.com/posts/1/links/tags',
                           'related' => 'http://www.example.com/posts/1/tags'
                          },
                          'data' => [
                            {type: 'tags', id: '1'},
                            {type: 'tags', id: '2'},
                            {type: 'tags', id: '3'}
                          ]
                       })
  end

  def test_flow_link_has_many_self_link_put
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][4]

    post post_1['links']['tags']['self'],
         {'data' => [{'type' => 'tags', 'id' => '10'}]}.to_json,
         "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status

    get post_1['links']['tags']['self']
    assert_equal 200, status
    assert_hash_equals(json_response,
                       {
                         'links' => {
                           'self' => 'http://www.example.com/posts/5/links/tags',
                           'related' => 'http://www.example.com/posts/5/tags'
                         },
                         'data' => [
                           {type: 'tags', id: '10'}
                         ]
                       })
  end

  def test_flow_self_formatted_route_1
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    get '/api/v6/purchase-orders'
    assert_equal 200, status
    po_1 = json_response['data'][0]

    get po_1['links']['self']
    assert_equal 200, status
    assert_hash_equals po_1, json_response['data']
  end

  def test_flow_self_formatted_route_2
    JSONAPI.configuration.route_format = :underscored_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    get '/api/v7/purchase_orders'
    assert_equal 200, status
    po_1 = json_response['data'][0]

    get po_1['links']['self']
    assert_equal 200, status
    assert_hash_equals po_1, json_response['data']
  end

  def test_post_formatted_keys
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'delivery-name' => 'ASDFG Corp',
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  end

  def test_post_formatted_keys_different_route_key_1
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :underscored_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'delivery_name' => 'ASDFG Corp',
             'type' => 'purchase_orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  end

  def test_post_formatted_keys_different_route_key_2
    JSONAPI.configuration.route_format = :underscored_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v7/purchase_orders',
         {
           'data' => {
             'delivery-name' => 'ASDFG Corp',
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  end

  def test_post_formatted_keys_wrong_format
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'delivery_name' => 'ASDFG Corp',
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 400, status
  end
end
