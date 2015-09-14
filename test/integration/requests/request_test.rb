require File.expand_path('../../../test_helper', __FILE__)

class RequestTest < ActionDispatch::IntegrationTest
  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
    JSONAPI.configuration.route_format = :underscored_route
    $test_user = Person.find(1)
  end

  def after_teardown
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.route_format = :underscored_route
  end

  def test_get
    get '/posts'
    assert_equal 200, status
  end

  def test_get_inflected_resource
    get '/api/v8/numeros_telefone'
    assert_equal 200, status
  end

  def test_get_nested_to_one
    get '/posts/1/author'
    assert_equal 200, status
  end

  def test_get_nested_to_many
    get '/posts/1/comments'
    assert_equal 200, status
  end

  def test_get_nested_to_many_bad_param
    get '/posts/1/comments?relationship=books'
    assert_equal 200, status
  end

  def test_get_underscored_key
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key
    get '/iso_currencies'
    assert_equal 200, status
    assert_equal 3, json_response['data'].size
  ensure
    JSONAPI.configuration = original_config
  end

  def test_get_underscored_key_filtered
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key
    get '/iso_currencies?filter[country_name]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country_name']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_get_camelized_key_filtered
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    get '/iso_currencies?filter[countryName]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['countryName']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_get_camelized_route_and_key_filtered
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    get '/api/v4/isoCurrencies?filter[countryName]=Canada'
    assert_equal 200, status
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['countryName']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_get_camelized_route_and_links
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.route_format = :camelized_route
    get '/api/v4/expenseEntries/1/relationships/isoCurrency'
    assert_equal 200, status
    assert_hash_equals({'links' => {
                         'self' => 'http://www.example.com/api/v4/expenseEntries/1/relationships/isoCurrency',
                         'related' => 'http://www.example.com/api/v4/expenseEntries/1/isoCurrency'
                       },
                       'data' => {
                          'type' => 'isoCurrencies',
                          'id' => 'USD'
                         }
                       }, json_response)
  ensure
    JSONAPI.configuration = original_config
  end

  def test_put_single_without_content_type
    put '/posts/3',
        {
          'data' => {
            'linkage' => {
              'type' => 'posts',
              'id' => '3',
            },
            'attributes' => {
              'title' => 'A great new Post'
            },
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
            'attributes' => {
              'title' => 'A great new Post'
            },
            'relationships' => {
              'tags' => {
                'data' => [
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
          'attributes' => {
            'title' => 'A great new Post'
          },
          'relationships' => {
            'tags' => {
              'data' => [
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
          'attributes' => {
            'title' => 'A great new Post',
            'body' => 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          'relationships' => {
            'author' => {'data' => {type: 'people', id: '3'}}
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
    assert_nil json_response['data']['attributes']['body']
    assert_nil json_response['data']['relationships']['post']['data']
    assert_nil json_response['data']['relationships']['author']['data']
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

  def test_update_relationship_without_content_type
    ruby = Section.find_by(name: 'ruby')
    patch '/posts/3/relationships/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json

    assert_equal 415, status
  end

  def test_patch_update_relationship_to_one
    ruby = Section.find_by(name: 'ruby')
    patch '/posts/3/relationships/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_put_update_relationship_to_one
    ruby = Section.find_by(name: 'ruby')
    put '/posts/3/relationships/section', { 'data' => {type: 'sections', id: ruby.id.to_s }}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_patch_update_relationship_to_many_acts_as_set
    # Comments are acts_as_set=false so PUT/PATCH should respond with 403

    rogue = Comment.find_by(body: 'Rogue Comment Here')
    patch '/posts/5/relationships/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 403, status
  end

  def test_post_update_relationship_to_many
    rogue = Comment.find_by(body: 'Rogue Comment Here')
    post '/posts/5/relationships/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  end

  def test_put_update_relationship_to_many_acts_as_set
    # Comments are acts_as_set=false so PUT/PATCH should respond with 403. Note: JR currently treats PUT and PATCH as equivalent

    rogue = Comment.find_by(body: 'Rogue Comment Here')
    put '/posts/5/relationships/comments', { 'data' => [{type: 'comments', id: rogue.id.to_s }]}.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

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
            'attributes' => {
              'title' => 'A great new Post'
            },
            'relationships' => {
              'tags' => {
                'data' => [
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
            'attributes' => {
              'title' => 'A great new Post'
            },
            'relationships' => {
              'tags' => {
                'data' => [
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
         'attributes' => {
           'title' => 'A great new Post'
         },
         'relationships' => {
           'author' => {'data' => {type: 'people', id: '3'}}
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
    assert_equal 901, json_response['data'].size
  end

  def test_pagination_offset_style
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books'
    assert_equal 200, status
    assert_equal JSONAPI.configuration.default_page_size, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_pagination_offset_style_offset
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[offset]=50'
    assert_equal 200, status
    assert_equal JSONAPI.configuration.default_page_size, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
  end

  def test_pagination_offset_style_offset_limit
    Api::V2::BookResource.paginator :offset
    get '/api/v2/books?page[offset]=50&page[limit]=20'
    assert_equal 200, status
    assert_equal 20, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
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
                 json_response['data'][1]['relationships']['book_comments']['links']['related']
  end

  def test_pagination_related_resources_data
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/1/book_comments?page[limit]=10'
    assert_equal 200, status
    assert_equal 10, json_response['data'].size
    assert_equal 'This is comment 18 on book 1.', json_response['data'][9]['attributes']['body']
  end

  def test_pagination_related_resources_links
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/1/book_comments?page[limit]=10'
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['first']
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=10', json_response['links']['next']
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=16', json_response['links']['last']
  end

  def test_pagination_related_resources_links_meta
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    get '/api/v2/books/1/book_comments?page[limit]=10'
    assert_equal 26, json_response['meta']['record_count']
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['first']
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=10', json_response['links']['next']
    assert_equal 'http://www.example.com/api/v2/books/1/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=16', json_response['links']['last']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_filter_related_resources
    JSONAPI.configuration.top_level_meta_include_record_count = true
    get '/api/v2/books/1/book_comments?filter[book]=2'
    assert_equal 0, json_response['meta']['record_count']
    get '/api/v2/books/1/book_comments?filter[book]=1&page[limit]=20'
    assert_equal 26, json_response['meta']['record_count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_pagination_related_resources_without_related
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/10/book_comments'
    assert_equal 200, status
    assert_nil json_response['links']['next']
    assert_equal 'http://www.example.com/api/v2/books/10/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['first']
    assert_equal 'http://www.example.com/api/v2/books/10/book_comments?page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['last']
  end

  def test_related_resource_alternate_relation_name_record_count
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.default_paginator = :paged
    JSONAPI.configuration.top_level_meta_include_record_count = true

    get '/api/v2/books/1/aliased_comments'
    assert_equal 200, status
    assert_equal 26, json_response['meta']['record_count']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_pagination_related_resources_data_includes
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books/1/book_comments?page[limit]=10&include=author,book'
    assert_equal 200, status
    assert_equal 10, json_response['data'].size
    assert_equal 'This is comment 18 on book 1.', json_response['data'][9]['attributes']['body']
  end

  def test_pagination_empty_results
    Api::V2::BookResource.paginator :offset
    Api::V2::BookCommentResource.paginator :offset
    get '/api/v2/books?filter[id]=2000&page[limit]=10'
    assert_equal 200, status
    assert_equal 0, json_response['data'].size
    assert_nil json_response['links']['next']
    assert_equal 'http://www.example.com/api/v2/books?filter%5Bid%5D=2000&page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['first']
    assert_equal 'http://www.example.com/api/v2/books?filter%5Bid%5D=2000&page%5Blimit%5D=10&page%5Boffset%5D=0', json_response['links']['last']
  end

  # def test_pagination_related_resources_data_includes
  #   Api::V2::BookResource.paginator :none
  #   Api::V2::BookCommentResource.paginator :none
  #   get '/api/v2/books?filter[]'
  #   assert_equal 200, status
  #   assert_equal 10, json_response['data'].size
  #   assert_equal 'This is comment 18 on book 1.', json_response['data'][9]['attributes']['body']
  # end


  def test_flow_self
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['links']['self']
    assert_equal 200, status
    assert_hash_equals post_1, json_response['data']
  end

  def test_flow_link_to_one_self_link
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['relationships']['author']['links']['self']
    assert_equal 200, status
    assert_hash_equals(json_response, {
                                      'links' => {
                                        'self' => 'http://www.example.com/posts/1/relationships/author',
                                        'related' => 'http://www.example.com/posts/1/author'
                                      },
                                      'data' => {type: 'people', id: '1'}
                                    })
  end

  def test_flow_link_to_many_self_link
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][0]

    get post_1['relationships']['tags']['links']['self']
    assert_equal 200, status
    assert_hash_equals(json_response,
                       {
                         'links' => {
                           'self' => 'http://www.example.com/posts/1/relationships/tags',
                           'related' => 'http://www.example.com/posts/1/tags'
                          },
                          'data' => [
                            {type: 'tags', id: '1'},
                            {type: 'tags', id: '2'},
                            {type: 'tags', id: '3'}
                          ]
                       })
  end

  def test_flow_link_to_many_self_link_put
    get '/posts'
    assert_equal 200, status
    post_1 = json_response['data'][4]

    post post_1['relationships']['tags']['links']['self'],
         {'data' => [{'type' => 'tags', 'id' => '10'}]}.to_json,
         "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status

    get post_1['relationships']['tags']['links']['self']
    assert_equal 200, status
    assert_hash_equals(json_response,
                       {
                         'links' => {
                           'self' => 'http://www.example.com/posts/5/relationships/tags',
                           'related' => 'http://www.example.com/posts/5/tags'
                         },
                         'data' => [
                           {type: 'tags', id: '10'}
                         ]
                       })
  end

  def test_flow_self_formatted_route_1
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    get '/api/v6/purchase-orders'
    assert_equal 200, status
    po_1 = json_response['data'][0]
    assert_equal 'purchase-orders', json_response['data'][0]['type']

    get po_1['links']['self']
    assert_equal 200, status
    assert_hash_equals po_1, json_response['data']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_flow_self_formatted_route_2
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :underscored_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    get '/api/v7/purchase_orders'
    assert_equal 200, status
    assert_equal 'purchase-orders', json_response['data'][0]['type']

    po_1 = json_response['data'][0]

    get po_1['links']['self']
    assert_equal 200, status
    assert_hash_equals po_1, json_response['data']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_flow_self_formatted_route_3
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :underscored_route
    JSONAPI.configuration.json_key_format = :underscored_key
    get '/api/v7/purchase_orders'
    assert_equal 200, status
    assert_equal 'purchase_orders', json_response['data'][0]['type']

    po_1 = json_response['data'][0]

    get po_1['links']['self']
    assert_equal 200, status
    assert_hash_equals po_1, json_response['data']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_post_formatted_keys
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'attributes' => {
               'delivery-name' => 'ASDFG Corp'
             },
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_post_formatted_keys_different_route_key_1
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :underscored_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'attributes' => {
               'delivery_name' => 'ASDFG Corp'
             },
             'type' => 'purchase_orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_post_formatted_keys_different_route_key_2
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :underscored_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v7/purchase_orders',
         {
           'data' => {
             'attributes' => {
               'delivery-name' => 'ASDFG Corp'
             },
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 201, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_post_formatted_keys_wrong_format
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders',
         {
           'data' => {
             'attributes' => {
               'delivery_name' => 'ASDFG Corp'
             },
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 400, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_patch_formatted_dasherized
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/purchase-orders/1',
         {
           'data' => {
             'id' => '1',
             'attributes' => {
               'delivery-name' => 'ASDFG Corp'
             },
             'type' => 'purchase-orders'
           }
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 200, status
  end

  def test_patch_formatted_dasherized_links
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/line-items/1',
          {
            'data' => {
              'id' => '1',
              'type' => 'line-items',
              'attributes' => {
                'item-cost' => '23.57'
              },
              'relationships' => {
                'purchase-order' => {
                  'data' => {'type' => 'purchase-orders', 'id' => '2'}
                }
              }
            }
          }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 200, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_patch_formatted_dasherized_replace_to_many
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/purchase-orders/2?include=line-items,order-flags',
          {
            'data' => {
              'id' => '2',
              'type' => 'purchase-orders',
              'relationships' => {
                'line-items' => {
                  'data' => [
                    {'type' => 'line-items', 'id' => '3'},
                    {'type' => 'line-items', 'id' => '4'}
                  ]
                },
                'order-flags' => {
                  'data' => [
                    {'type' => 'order-flags', 'id' => '1'},
                    {'type' => 'order-flags', 'id' => '2'}
                  ]
                }
              }
            }
          }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 200, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_patch_formatted_dasherized_replace_to_many_computed_relation
    $original_test_user = $test_user
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/purchase-orders/2?include=line-items,order-flags',
          {
            'data' => {
              'id' => '2',
              'type' => 'purchase-orders',
              'relationships' => {
                'line-items' => {
                  'data' => [
                    {'type' => 'line-items', 'id' => '3'},
                    {'type' => 'line-items', 'id' => '4'}
                  ]
                },
                'order-flags' => {
                  'data' => [
                    {'type' => 'order-flags', 'id' => '1'},
                    {'type' => 'order-flags', 'id' => '2'}
                  ]
                }
              }
            }
          }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 200, status
  ensure
    JSONAPI.configuration = original_config
    $test_user = $original_test_user
  end

  def test_post_to_many_link
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders/3/relationships/line-items',
          {
            'data' => [
              {'type' => 'line-items', 'id' => '3'},
              {'type' => 'line-items', 'id' => '4'}
            ]
          }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_post_computed_relation_to_many
    $original_test_user = $test_user
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    post '/api/v6/purchase-orders/4/relationships/line-items',
         {
           'data' => [
             {'type' => 'line-items', 'id' => '5'},
             {'type' => 'line-items', 'id' => '6'}
           ]
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  ensure
    JSONAPI.configuration = original_config
    $test_user = $original_test_user
  end

  def test_patch_to_many_link
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/purchase-orders/3/relationships/order-flags',
         {
           'data' => [
             {'type' => 'order-flags', 'id' => '1'},
             {'type' => 'order-flags', 'id' => '2'}
           ]
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_patch_to_many_link_computed_relation
    $original_test_user = $test_user
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/purchase-orders/4/relationships/order-flags',
          {
            'data' => [
              {'type' => 'order-flags', 'id' => '1'},
              {'type' => 'order-flags', 'id' => '2'}
            ]
          }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  ensure
    JSONAPI.configuration = original_config
    $test_user = $original_test_user
  end

  def test_patch_to_one
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.route_format = :dasherized_route
    JSONAPI.configuration.json_key_format = :dasherized_key
    patch '/api/v6/line-items/5/relationships/purchase-order',
         {
           'data' => {'type' => 'purchase-orders', 'id' => '3'}
         }.to_json, "CONTENT_TYPE" => JSONAPI::MEDIA_TYPE

    assert_equal 204, status
  ensure
    JSONAPI.configuration = original_config
  end

  def test_include_parameter_allowed
    get '/api/v2/books/1/book_comments?include=author'
    assert_equal 200, status
  end

  def test_include_parameter_not_allowed
    JSONAPI.configuration.allow_include = false
    get '/api/v2/books/1/book_comments?include=author'
    assert_equal 400, status
  ensure
    JSONAPI.configuration.allow_include = true
  end

  def test_filter_parameter_not_allowed
    JSONAPI.configuration.allow_filter = false
    get '/api/v2/books?filter[author]=1'
    assert_equal 400, status
  ensure
    JSONAPI.configuration.allow_filter = true
  end

  def test_sort_parameter_not_allowed
    JSONAPI.configuration.allow_sort = false
    get '/api/v2/books?sort=title'
    assert_equal 400, status
  ensure
    JSONAPI.configuration.allow_sort = true
  end
end
