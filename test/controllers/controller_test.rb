require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/active_record', __FILE__)

def set_content_type_header!
  @request.headers['Content-Type'] = JSONAPI::MEDIA_TYPE
end

class PostsControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_response :success
    assert json_response['data'].is_a?(Array)
  end

  def test_index_filter_with_empty_result
    get :index, {filter: {title: 'post that does not exist'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 0, json_response['data'].size
  end

  def test_index_filter_by_id
    get :index, {filter: {id: '1'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_title
    get :index, {filter: {title: 'New post'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_ids
    get :index, {filter: {ids: '1,2'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 2, json_response['data'].size
  end

  def test_index_filter_by_ids_and_include_related
    get :index, {filter: {id: '2'}, include: 'comments'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_by_ids_and_include_related_different_type
    get :index, {filter: {id: '1,2'}, include: 'author'}
    assert_response :success
    assert_equal 2, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_by_ids_and_fields
    get :index, {filter: {id: '1,2'}, 'fields' => 'id,title,author'}
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, title, links
    assert_equal 4, json_response['data'][0].size
    assert json_response['data'][0].has_key?('type')
    assert json_response['data'][0].has_key?('id')
    assert json_response['data'][0].has_key?('title')
    assert json_response['data'][0].has_key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_type
    get :index, {filter: {id: '1,2'}, 'fields' => {'posts' => 'id,title,author'}}
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, title, links
    assert_equal 4, json_response['data'][0].size
    assert json_response['data'][0].has_key?('type')
    assert json_response['data'][0].has_key?('id')
    assert json_response['data'][0].has_key?('title')
    assert json_response['data'][0].has_key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_unrelated_type
    get :index, {filter: {id: '1,2'}, 'fields' => {'currencies' => 'code'}}
    assert_response :bad_request
    assert_match /currencies is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_by_ids_and_fields_2
    get :index, {filter: {id: '1,2'}, 'fields' => 'author'}
    assert_response :success
    assert_equal 2, json_response['data'].size

    # links, id, type
    assert_equal 3, json_response['data'][0].size
    assert json_response['data'][0].has_key?('type')
    assert json_response['data'][0].has_key?('id')
    assert json_response['data'][0]['links'].has_key?('author')
  end

  def test_filter_association_single
    get :index, {filter: {tags: '5,1'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_match /New post/, response.body
    assert_match /JR Solves your serialization woes!/, response.body
    assert_match /JR How To/, response.body
  end

  def test_filter_associations_multiple
    get :index, {filter: {tags: '5,1', comments: '3'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_match /JR Solves your serialization woes!/, response.body
  end

  def test_filter_associations_multiple_not_found
    get :index, {filter: {tags: '1', comments: '3'}}
    assert_response :success
    assert_equal 0, json_response['data'].size
  end

  def test_bad_filter
    get :index, {filter: {post_ids: '1,2'}}
    assert_response :bad_request
    assert_match /post_ids is not allowed/, response.body
  end

  def test_bad_filter_value_not_integer_array
    get :index, {filter: {id: 'asdfg'}}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_integer
    get :index, {filter: {id: 'asdfg'}}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_found_array
    get :index, {filter: {id: '5412333'}}
    assert_response :not_found
    assert_match /5412333 could not be found/, response.body
  end

  def test_bad_filter_value_not_found
    get :index, {filter: {id: '5412333'}}
    assert_response :not_found
    assert_match /5412333 could not be found/, json_response['errors'][0]['detail']
  end

  def test_index_malformed_fields
    get :index, {filter: {id: '1,2'}, 'fields' => 'posts'}
    assert_response :bad_request
    assert_match /posts is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_field_not_supported
    get :index, {filter: {id: '1,2'}, 'fields' => {'posts' => 'id,title,rank,author'}}
    assert_response :bad_request
    assert_match /rank is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_resource_not_supported
    get :index, {filter: {id: '1,2'}, 'fields' => {'posters' => 'id,title'}}
    assert_response :bad_request
    assert_match /posters is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_on_association
    get :index, {filter: {author: '1'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_asc
    get :index, {sort: '+title'}

    assert_response :success
    assert_equal "Delete This Later - Multiple2-1", json_response['data'][0]['title']
  end

  def test_sorting_desc
    get :index, {sort: '-title'}

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['title']
  end

  def test_sorting_by_multiple_fields
    get :index, {sort: '+title,+body'}

    assert_response :success
    assert_equal '8', json_response['data'][0]['id']
  end

  def test_invalid_sort_param
    get :index, {sort: '+asdfg'}

    assert_response :bad_request
    assert_match /asdfg is not a valid sort criteria for post/, response.body
  end

  def test_invalid_sort_param_missing_direction
    get :index, {sort: 'title'}

    assert_response :bad_request
    assert_match /title must start with a direction/, response.body
  end

  def test_excluded_sort_param
    get :index, {sort: '+id'}

    assert_response :bad_request
    assert_match /id is not a valid sort criteria for post/, response.body
  end

  # ToDo: test validating the parameter values
  # def test_index_invalid_filter_value
  #   get :index, {ids: [1,'asdfg1']}
  #   assert_response :bad_request
  # end

  def test_show_single
    get :show, {id: '1'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['title']
    assert_equal 'A body!!!', json_response['data']['body']
    assert_nil json_response['included']
  end

  def test_show_single_with_includes
    get :show, {id: '1', include: 'comments'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['title']
    assert_equal 'A body!!!', json_response['data']['body']
    assert_nil json_response['data']['links']['tags']['ids']
    assert_equal ['1', '2'], json_response['data']['links']['comments']['ids']
    assert_equal 2, json_response['included'].size
  end

  def test_show_single_with_fields
    get :show, {id: '1', fields: 'author'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_nil json_response['data']['title']
    assert_nil json_response['data']['body']
    assert_equal '1', json_response['data']['links']['author']['id']
  end

  def test_show_single_invalid_id_format
    get :show, {id: 'asdfg'}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_show_single_missing_record
    get :show, {id: '5412333'}
    assert_response :not_found
    assert_match /record identified by 5412333 could not be found/, response.body
  end

  def test_show_malformed_fields_not_list
    get :show, {id: '1', 'fields' => ''}
    assert_response :bad_request
    assert_match /nil is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_show_malformed_fields_type_not_list
    get :show, {id: '1', 'fields' => {'posts' => ''}}
    assert_response :bad_request
    assert_match /nil is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_create_simple
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal 'JR is Great', json_response['data']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['body']
  end

  def test_create_link_to_missing_object
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '304567'}
             }
           }
         }

    assert_response :unprocessable_entity
    # Todo: check if this validation is working
    assert_match /author - can't be blank/, response.body
  end

  def test_create_extra_param
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             asdfg: 'aaaa',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_create_with_invalid_data
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JSONAPIResources is the greatest thing...',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: nil
             }
           }
         }

    assert_response :unprocessable_entity

    assert_equal "/author", json_response['errors'][0]['path']
    assert_equal "can't be blank", json_response['errors'][0]['detail']
    assert_equal "author - can't be blank", json_response['errors'][0]['title']

    assert_equal "/title", json_response['errors'][1]['path']
    assert_equal "is too long (maximum is 35 characters)", json_response['errors'][1]['detail']
    assert_equal "title - is too long (maximum is 35 characters)", json_response['errors'][1]['title']
  end

  def test_create_multiple
    set_content_type_header!
    post :create,
         {
           data: [
             {
               type: 'posts',
               title: 'JR is Great',
               body: 'JSONAPIResources is the greatest thing since unsliced bread.',
               links: {
                 author: {type: 'people', id: '3'}
               }
             },
             {
               type: 'posts',
               title: 'Ember is Great',
               body: 'Ember is the greatest thing since unsliced bread.',
               links: {
                 author: {type: 'people', id: '3'}
               }
             }
           ]
         }

    assert_response :created
    assert json_response['data'].is_a?(Array)
    assert_equal json_response['data'].size, 2
    assert_equal json_response['data'][0]['links']['author']['id'], '3'
    assert_match /JR is Great/, response.body
    assert_match /Ember is Great/, response.body
  end

  def test_create_multiple_wrong_case
    set_content_type_header!
    post :create,
         {
           data: [
             {
               type: 'posts',
               Title: 'JR is Great',
               body: 'JSONAPIResources is the greatest thing since unsliced bread.',
               links: {
                 author: {type: 'people', id: '3'}
               }
             },
             {
               type: 'posts',
               title: 'Ember is Great',
               BODY: 'Ember is the greatest thing since unsliced bread.',
               links: {
                 author: {type: 'people', id: '3'}
               }
             }
           ]
         }

    assert_response :bad_request
    assert_match /Title/, json_response['errors'][0]['detail']
  end

  def test_create_simple_missing_posts
    set_content_type_header!
    post :create,
         {
           data_spelled_wrong: {
             type: 'posts',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, json_response['errors'][0]['detail']
  end

  def test_create_simple_wrong_type
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts_spelled_wrong',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :bad_request
    assert_match /posts_spelled_wrong is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_create_simple_missing_type
    set_content_type_header!
    post :create,
         {
           data: {
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :bad_request
    assert_match /The required parameter, type, is missing./, json_response['errors'][0]['detail']
  end

  def test_create_simple_unpermitted_attributes
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             subject: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'}
             }
           }
         }

    assert_response :bad_request
    assert_match /subject/, json_response['errors'][0]['detail']
  end

  def test_create_with_links_has_many_type_ids
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'},
               tags: {type: 'tags', ids: [3, 4]}
             }
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal 'JR is Great', json_response['data']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['body']
  end

  def test_create_with_links_has_many_array
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: {type: 'people', id: '3'},
               tags: [{type: 'tags', id: '3'}, {type: 'tags', id: '4'}]
             }
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal 'JR is Great', json_response['data']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['body']
  end

  def test_create_with_links_include_and_fields
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR is Great!',
             body: 'JSONAPIResources is the greatest thing since unsliced bread!',
             links: {
               author: {type: 'people', id: '3'},
               tags: {type: 'tags', ids: [3, 4]}
             }
           },
           include: 'author,author.posts',
           fields: 'id,title,author'
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal 'JR is Great!', json_response['data']['title']
    assert_not_nil json_response['included'].size
  end

  def test_update_with_links
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data: {
            id: '3',
            type: 'posts',
            title: 'A great new Post',
            links: {
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          },
          include: 'tags'
        }

    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal javascript.id.to_s, json_response['data']['links']['section']['id']
    assert_equal 'A great new Post', json_response['data']['title']
    assert_equal 'AAAA', json_response['data']['body']
    assert matches_array?(['3', '4'], json_response['data']['links']['tags']['ids'])
  end

  def test_update_remove_links
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: 3,
            title: 'A great new Post',
            links: {
              section: nil,
              tags: []
            }
          },
          include: 'tags'
        }

    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['author']['id']
    assert_equal nil, json_response['data']['links']['section']['id']
    assert_equal 'A great new Post', json_response['data']['title']
    assert_equal 'AAAA', json_response['data']['body']
    assert matches_array?([], json_response['data']['links']['tags']['ids'])
  end

  def test_update_relationship_has_one
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    assert_not_equal ruby.id, post_object.section_id

    put :update_association, {post_id: 3, association: 'section', data: {type: 'sections', id: "#{ruby.id}"}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_update_relationship_has_one_invalid_links_hash_keys_ids
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'section', data: {type: 'sections', ids: 'foo'}}

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_has_one_invalid_links_hash_count
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'section', data: {type: 'sections'}}

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_has_one_invalid_links_hash_keys_type_mismatch
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'section', data: {type: 'comment', id: '3'}}

    assert_response :bad_request
    assert_match /Type Mismatch/, response.body
  end

  def test_update_nil_has_many_links
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: 3,
            links: {
              tags: nil
            }
          }
        }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_bad_hash_has_many_links
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: 3,
            links: {
              tags: {typ: 'bad link', idd: 'as'}
            }
          }
        }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_other_has_many_links
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: 3,
            links: {
              tags: 'bad link'
            }
          }
        }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_has_one_singular_param_id_nil
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section = ruby
    post_object.save!

    put :update_association, {post_id: 3, association: 'section', data: {type: 'sections', id: nil}}

    assert_response :no_content
    assert_equal nil, post_object.reload.section_id
  end

  def test_update_relationship_has_one_data_nil
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section = ruby
    post_object.save!

    put :update_association, {post_id: 3, association: 'section', data: nil}

    assert_response :no_content
    assert_equal nil, post_object.reload.section_id
  end

  def test_remove_relationship_has_one
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = ruby.id
    post_object.save!

    put :destroy_association, {post_id: 3, association: 'section'}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal nil, post_object.section_id
  end

  def test_update_relationship_has_one_singular_param
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = nil
    post_object.save!

    put :update_association, {post_id: 3, association: 'section', data: {type: 'sections', id: "#{ruby.id}"}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_update_relationship_has_many_join_table_single
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: []}}
    assert_response :no_content

    post_object = Post.find(3)
    assert_equal 0, post_object.tags.length

    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [2]}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 1, post_object.tags.length

    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [5]}}

    assert_response :no_content
    post_object = Post.find(3)
    tags = post_object.tags.collect { |tag| tag.id }
    assert_equal 1, tags.length
    assert matches_array? [5], tags
  end

  def test_update_relationship_has_many_join_table_homogenous
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [2, 3]}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }
  end

  def test_update_relationship_has_many_join_table_heterogenous
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_has_many_join_table
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [2, 3]}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [5]}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 3, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3, 5], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_has_many_mismatched_type
    set_content_type_header!
    post :create_association, {post_id: 3, association: 'tags', data: {type: 'comments', ids: [5]}}

    assert_response :bad_request
    assert_match /Type Mismatch/, response.body
  end

  def test_create_relationship_has_many_missing_id
    set_content_type_header!
    post :create_association, {post_id: 3, association: 'tags', data: {type: 'tags', idds: [5]}}

    assert_response :bad_request
    assert_match /The required parameter, ids, is missing/, response.body
  end

  def test_create_relationship_has_many_missing_data
    set_content_type_header!
    post :create_association, {post_id: 3, association: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_create_relationship_has_many_join
    set_content_type_header!
    post :create_association, {post_id: 4, association: 'tags', data: {type: 'tags', ids: [1, 2, 3]}}
    assert_response :no_content
  end

  def test_create_relationship_has_many_join_table_record_exists
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [2, 3]}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_association, {post_id: 3, association: 'tags', data: {type: 'tags', ids: [5, 2]}}

    assert_response :bad_request
    assert_match /The relation to 2 already exists./, response.body
  end

  def test_update_relationship_has_many_missing_tags
    set_content_type_header!
    put :update_association, {post_id: 3, association: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_delete_relationship_has_many
    set_content_type_header!
    put :update_association, {post_id: 9, association: 'tags', data: {type: 'tags', ids: [2, 3]}}
    assert_response :no_content
    p = Post.find(9)
    assert_equal [2, 3], p.tag_ids

    delete :destroy_association, {post_id: 9, association: 'tags', keys: '3'}

    p.reload
    assert_response :no_content
    assert_equal [2], p.tag_ids
  end

  def test_delete_relationship_has_many_does_not_exist
    set_content_type_header!
    put :update_association, {post_id: 9, association: 'tags', data: {type: 'tags', ids: [2, 3]}}
    assert_response :no_content
    p = Post.find(9)
    assert_equal [2, 3], p.tag_ids

    delete :destroy_association, {post_id: 9, association: 'tags', keys: '4'}

    p.reload
    assert_response :not_found
    assert_equal [2, 3], p.tag_ids
  end

  def test_delete_relationship_has_many_with_empty_data
    set_content_type_header!
    put :update_association, {post_id: 9, association: 'tags', data: {type: 'tags', ids: [2, 3]}}
    assert_response :no_content
    p = Post.find(9)
    assert_equal [2, 3], p.tag_ids

    put :update_association, {post_id: 9, association: 'tags', data: [] }

    p.reload
    assert_response :no_content
    assert_equal [], p.tag_ids
  end

  def test_update_mismatched_keys
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: 2,
            title: 'A great new Post',
            links: {
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /The URL does not support the key 2/, response.body
  end

  def test_update_extra_param
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: '3',
            asdfg: 'aaaa',
            title: 'A great new Post',
            links: {
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_extra_param_in_links
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: '3',
            title: 'A great new Post',
            links: {
              asdfg: 'aaaa',
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_missing_param
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data_spelled_wrong: {
            type: 'posts',
            title: 'A great new Post',
            links: {
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_update_missing_key
    set_content_type_header!

    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            title: 'A great new Post'
          }
        }

    assert_response :bad_request
    assert_match /The resource object does not contain a key/, response.body
  end

  def test_update_missing_type
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          data: {
            id: '3',
            type_spelled_wrong: 'posts',
            title: 'A great new Post',
            links: {
              section: {type: 'sections', id: "#{javascript.id}"},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /The required parameter, type, is missing./, response.body
  end

  def test_update_multiple
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          data: [
            {
              type: 'posts',
              id: 3,
              title: 'A great new Post QWERTY',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            },
            {
              type: 'posts',
              id: 9,
              title: 'A great new Post ASDFG',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            }
          ],
          include: 'tags'
        }

    assert_response :success
    assert_equal json_response['data'].size, 2
    assert_equal json_response['data'][0]['links']['author']['id'], '3'
    assert_equal json_response['data'][0]['links']['section']['id'], javascript.id.to_s
    assert_equal json_response['data'][0]['title'], 'A great new Post QWERTY'
    assert_equal json_response['data'][0]['body'], 'AAAA'
    assert_equal json_response['data'][0]['links']['tags']['ids'], ['3', '4']

    assert_equal json_response['data'][1]['links']['author']['id'], '3'
    assert_equal json_response['data'][1]['links']['section']['id'], javascript.id.to_s
    assert_equal json_response['data'][1]['title'], 'A great new Post ASDFG'
    assert_equal json_response['data'][1]['body'], 'AAAA'
    assert_equal json_response['data'][1]['links']['tags']['ids'], ['3', '4']
  end

  def test_update_multiple_missing_keys
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          data: [
            {
              type: 'posts',
              title: 'A great new Post ASDFG',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            },
            {
              type: 'posts',
              title: 'A great new Post QWERTY',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            }
          ]}

    assert_response :bad_request
    assert_match /A key is required/, response.body
  end

  def test_update_mismatch_keys
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          data: [
            {
              type: 'posts',
              id: 3,
              title: 'A great new Post ASDFG',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            },
            {
              type: 'posts',
              id: 8,
              title: 'A great new Post QWERTY',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            }
          ]}

    assert_response :bad_request
    assert_match /The URL does not support the key 8/, response.body
  end

  def test_update_multiple_count_mismatch
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9, 2],
          data: [
            {
              type: 'posts',
              id: 3,
              title: 'A great new Post QWERTY',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            },
            {
              type: 'posts',
              id: 9,
              title: 'A great new Post ASDFG',
              links: {
                section: {type: 'sections', id: "#{javascript.id}"},
                tags: {type: 'tags', ids: [3, 4]}
              }
            }
          ]}

    assert_response :bad_request
    assert_match /Count to key mismatch/, response.body
  end

  def test_update_unpermitted_attributes
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            id: '3',
            subject: 'A great new Post',
            links: {
              author: {type: 'people', id: '1'},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
    assert_match /author is not allowed./, response.body
    assert_match /subject is not allowed./, response.body
  end

  def test_update_bad_attributes
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            type: 'posts',
            subject: 'A great new Post',
            linked_objects: {
              author: {type: 'people', id: '1'},
              tags: {type: 'tags', ids: [3, 4]}
            }
          }
        }

    assert_response :bad_request
  end

  def test_delete_single
    initial_count = Post.count
    delete :destroy, {id: '4'}
    assert_response :no_content
    assert_equal initial_count - 1, Post.count
  end

  def test_delete_multiple
    initial_count = Post.count
    delete :destroy, {id: '5,6'}
    assert_response :no_content
    assert_equal initial_count - 2, Post.count
  end

  def test_delete_multiple_one_does_not_exist
    initial_count = Post.count
    delete :destroy, {id: '5,6,99999'}
    assert_response :not_found
    assert_equal initial_count, Post.count
  end

  def test_delete_extra_param
    initial_count = Post.count
    delete :destroy, {id: '4', asdfg: 'aaaa'}
    assert_response :bad_request
    assert_equal initial_count, Post.count
  end

  def test_show_has_one_relationship
    get :show_association, {post_id: '1', association: 'author'}
    assert_response :success
    assert_hash_equals json_response,
                       {data: {
                           type: 'people',
                           id: '1',
                           self: 'http://test.host/posts/1/links/author',
                           related: 'http://test.host/posts/1/author'
                         }
                       }
  end

  def test_show_has_many_relationship
    get :show_association, {post_id: '1', association: 'tags'}
    assert_response :success
    assert_hash_equals json_response,
                       {data: {
                           type: 'tags',
                           ids: ['1', '2', '3'],
                           self: 'http://test.host/posts/1/links/tags',
                           related: 'http://test.host/posts/1/tags'
                         }
                       }
  end
end

class TagsControllerTest < ActionController::TestCase
  def test_tags_index
    get :index, {filter: {id: '6,7,8,9'}, include: 'posts,posts.tags,posts.author.posts'}
    assert_response :success
    assert_equal 4, json_response['data'].size
    assert_equal 2, json_response['included'].size
  end

  def test_tags_show_multiple
    get :show, {id: '6,7,8,9'}
    assert_response :bad_request
    assert_match /6,7,8,9 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_include
    get :show, {id: '6,7,8,9', include: 'posts,posts.tags,posts.author.posts'}
    assert_response :bad_request
    assert_match /6,7,8,9 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids
    get :show, {id: '6,99,9,100'}
    assert_response :bad_request
    assert_match /6,99,9,100 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids_at_the_beginning
    get :show, {id: '99,9,100'}
    assert_response :bad_request
    assert_match /99,9,100 is not a valid value for id/, response.body
  end
end

class ExpenseEntriesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_expense_entries_index
    get :index
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 2, json_response['data'].size
  end

  def test_expense_entries_show
    get :show, {id: 1}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_expense_entries_show_include
    get :show, {id: 1, include: 'isoCurrency,employee'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_bad_include_missing_association
    get :show, {id: 1, include: 'isoCurrencies,employees'}
    assert_response :bad_request
    assert_match /isoCurrencies is not a valid association of expenseEntries/, json_response['errors'][0]['detail']
    assert_match /employees is not a valid association of expenseEntries/, json_response['errors'][1]['detail']
  end

  def test_expense_entries_show_bad_include_missing_sub_association
    get :show, {id: 1, include: 'isoCurrency,employee.post'}
    assert_response :bad_request
    assert_match /post is not a valid association of people/, json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_fields
    get :show, {id: 1, include: 'isoCurrency,employee', 'fields' => 'transactionDate'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert json_response['data'].has_key?('transactionDate')
  end

  def test_expense_entries_show_fields_type
    get :show, {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate'}}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert json_response['data'].has_key?('transactionDate')
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_fields_type_many
    get :show, {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate',
                                                                     'isoCurrencies' => 'id,name'}}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert json_response['data'].has_key?('transactionDate')
    assert_equal 2, json_response['included'].size
  end

  def test_create_expense_entries_underscored
    set_content_type_header!
    JSONAPI.configuration.json_key_format = :underscored_key

    post :create,
         {
           data: {
             type: 'expense_entries',
             transaction_date: '2014/04/15',
             cost: 50.58,
             links: {
               employee: {type: 'people', id: '3'},
               iso_currency: {type: 'iso_currencies', id: 'USD'}
             }
           },
           include: 'iso_currency',
           fields: 'id,transaction_date,iso_currency,cost,employee'
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['employee']['id']
    assert_equal 'USD', json_response['data']['links']['iso_currency']['id']
    assert_equal 50.58, json_response['data']['cost']

    delete :destroy, {id: json_response['data']['id']}
    assert_response :no_content
  end

  def test_create_expense_entries_camelized_key
    set_content_type_header!
    JSONAPI.configuration.json_key_format = :camelized_key

    post :create,
         {
           data: {
             type: 'expense_entries',
             transactionDate: '2014/04/15',
             cost: 50.58,
             links: {
               employee: {type: 'people', id: '3'},
               isoCurrency: {type: 'iso_currencies', id: 'USD'}
             }
           },
           include: 'isoCurrency',
           fields: 'id,transactionDate,isoCurrency,cost,employee'
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['employee']['id']
    assert_equal 'USD', json_response['data']['links']['isoCurrency']['id']
    assert_equal 50.58, json_response['data']['cost']

    delete :destroy, {id: json_response['data']['id']}
    assert_response :no_content
  end

  def test_create_expense_entries_dasherized_key
    set_content_type_header!
    JSONAPI.configuration.json_key_format = :dasherized_key

    post :create,
         {
           data: {
             type: 'expense_entries',
             'transaction-date' => '2014/04/15',
             cost: 50.58,
             links: {
               employee: {type: 'people', id: '3'},
               'iso-currency' => {type: 'iso_currencies', id: 'USD'}
             }
           },
           include: 'iso-currency',
           fields: 'id,transaction-date,iso-currency,cost,employee'
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['employee']['id']
    assert_equal 'USD', json_response['data']['links']['iso-currency']['id']
    assert_equal 50.58, json_response['data']['cost']

    delete :destroy, {id: json_response['data']['id']}
    assert_response :no_content
  end
end

class IsoCurrenciesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_currencies_show
    get :show, {code: 'USD'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_currencies_json_key_underscored_sort
    JSONAPI.configuration.json_key_format = :underscored_key
    get :index, {sort: '+country_name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['country_name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['country_name']
    assert_equal 'United States', json_response['data'][2]['country_name']

    # reverse sort
    get :index, {sort: '-country_name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['country_name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['country_name']
    assert_equal 'Canada', json_response['data'][2]['country_name']
  end

  def test_currencies_json_key_dasherized_sort
    JSONAPI.configuration.json_key_format = :dasherized_key
    get :index, {sort: '+country-name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['country-name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['country-name']
    assert_equal 'United States', json_response['data'][2]['country-name']

    # reverse sort
    get :index, {sort: '-country-name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['country-name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['country-name']
    assert_equal 'Canada', json_response['data'][2]['country-name']
  end

  def test_currencies_json_key_custom_json_key_sort
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    get :index, {sort: '+CountryName'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['CountryName']
    assert_equal 'Euro Member Countries', json_response['data'][1]['CountryName']
    assert_equal 'United States', json_response['data'][2]['CountryName']

    # reverse sort
    get :index, {sort: '-CountryName'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['CountryName']
    assert_equal 'Euro Member Countries', json_response['data'][1]['CountryName']
    assert_equal 'Canada', json_response['data'][2]['CountryName']
  end

  def test_currencies_json_key_underscored_filter
    JSONAPI.configuration.json_key_format = :underscored_key
    get :index, {filter: {country_name: 'Canada'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['country_name']
  end

  def test_currencies_json_key_camelized_key_filter
    JSONAPI.configuration.json_key_format = :camelized_key
    get :index, {filter: {'countryName' => 'Canada'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['countryName']
  end

  def test_currencies_json_key_custom_json_key_filter
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    get :index, {filter: {'CountryName' => 'Canada'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['CountryName']
  end
end

class PeopleControllerTest < ActionController::TestCase
  def test_create_validations
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'people',
             name: 'Steve Jobs',
             email: 'sj@email.zzz',
             dateJoined: DateTime.parse('2014-1-30 4:20:00 UTC +00:00')
           }
         }

    assert_response :success
  end

  def test_create_validations_missing_attribute
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'people',
             email: 'sj@email.zzz'
           }
         }

    assert_response :unprocessable_entity
    assert_equal 2, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][1]['code']
    assert_match /date_joined - can't be blank/, response.body
    assert_match /name - can't be blank/, response.body
  end

  def test_update_validations_missing_attribute
    set_content_type_header!
    put :update,
        {
          id: 3,
          data: {
            id: '3',
            type: 'people',
            name: ''
          }
        }

    assert_response :unprocessable_entity
    assert_equal 1, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_match /name - can't be blank/, response.body
  end

  def test_delete_locked
    initial_count = Person.count
    delete :destroy, {id: '3'}
    assert_response :locked
    assert_equal initial_count, Person.count
  end

  def test_invalid_filter_value
    get :index, {filter: {name: 'L'}}
    assert_response :bad_request
  end

  def test_valid_filter_value
    get :index, {filter: {name: 'Joe Author'}}
    assert_response :success
    assert_equal json_response['data'].size, 1
    assert_equal json_response['data'][0]['id'], '1'
    assert_equal json_response['data'][0]['name'], 'Joe Author'
  end
end

class Api::V5::AuthorsControllerTest < ActionController::TestCase
  def test_including_resource_that_is_a_direct_relationship
    get :show, { id: '1', include: "preferences" }
    assert_equal response.status, 200
    assert_equal 1, json_response['included'].size
  end
end

class Api::V5::PostsControllerTest < ActionController::TestCase
  def test_including_resource_that_is_not_a_direct_relationship
    id = 1
    post = ::Post.find(id)
    assert !post.author.nil?
    assert !post.author.preferences.nil?
    get :show, { id: id, include: "author.preferences" }
    assert_equal response.status, 200
  end
end

class Api::V5::AuthorsControllerTest < ActionController::TestCase
  def test_get_person_as_author
    get :index, {filter: {id: '1'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 'authors', json_response['data'][0]['type']
    assert_equal 'Joe Author', json_response['data'][0]['name']
    assert_equal nil, json_response['data'][0]['email']
  end

  def test_get_person_as_author_by_name_filter
    get :index, {filter: {name: 'thor'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 'Joe Author', json_response['data'][0]['name']
  end
end

class BreedsControllerTest < ActionController::TestCase
  # Note: Breed names go through the TitleValueFormatter

  def test_poro_index
    get :index
    assert_response :success
    assert_equal '0', json_response['data'][0]['id']
    assert_equal 'Persian', json_response['data'][0]['name']
  end

  def test_poro_show
    get :show, {id: '0'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '0', json_response['data']['id']
    assert_equal 'Persian', json_response['data']['name']
  end

  def test_poro_show_multiple
    get :show, {id: '0,2'}

    assert_response :bad_request
    assert_match /0,2 is not a valid value for id/, response.body
  end

  def test_poro_create_simple
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'breeds',
             name: 'tabby'
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Tabby', json_response['data']['name']
  end

  def test_poro_create_update
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'breeds',
             name: 'CALIC'
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Calic', json_response['data']['name']

    put :update,
        {
          id: json_response['data']['id'],
          data: {
            id: json_response['data']['id'],
            type: 'breeds',
            name: 'calico'
          }
        }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Calico', json_response['data']['name']
  end

  def test_poro_delete
    initial_count = $breed_data.breeds.keys.count
    delete :destroy, {id: '3'}
    assert_response :no_content
    assert_equal initial_count - 1, $breed_data.breeds.keys.count
  end

end

class Api::V2::PreferencesControllerTest < ActionController::TestCase
  def test_show_singleton_resource_without_id
    get :show
    assert_response :success
  end
end

class Api::V1::PostsControllerTest < ActionController::TestCase
  def test_show_post_namespaced
    get :show, {id: '1'}
    assert_response :success
    assert_equal 'http://test.host/api/v1/posts/1/links/writer', json_response['data']['links']['writer']['self']
  end

  def test_show_post_namespaced_include
    get :show, {id: '1', include: 'writer'}
    assert_response :success
    assert_equal '1', json_response['data']['links']['writer']['id']
    assert_nil json_response['data']['links']['tags']
    assert_equal '1', json_response['included'][0]['id']
    assert_equal 'writers', json_response['included'][0]['type']
    assert_equal 'joe@xyz.fake', json_response['included'][0]['email']
  end

  def test_index_filter_on_association_namespaced
    get :index, {filter: {writer: '1'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_desc_namespaced
    get :index, {sort: '-title'}

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['title']
  end

  def test_create_simple_namespaced
    set_content_type_header!
    post :create,
         {
           data: {
             type: 'posts',
             title: 'JR - now with Namespacing',
             body: 'JSONAPIResources is the greatest thing since unsliced bread now that it has namespaced resources.',
             links: {
               writer: {type: 'writers', id: '3'}
             }
           }
         }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['links']['writer']['id']
    assert_equal 'JR - now with Namespacing', json_response['data']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread now that it has namespaced resources.',
                 json_response['data']['body']
  end

end

class FactsControllerTest < ActionController::TestCase
  def test_type_formatting
    get :show, {id: '1'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Jane Author', json_response['data']['spouseName']
    assert_equal 'First man to run across Antartica.', json_response['data']['bio']
    assert_equal 23.89/45.6, json_response['data']['qualityRating']
    assert_equal 47000.56, json_response['data']['salary']
    assert_equal '2013-08-07T20:25:00.000Z', json_response['data']['dateTimeJoined']
    assert_equal '1965-06-30', json_response['data']['birthday']
    assert_equal '2000-01-01T20:00:00Z', json_response['data']['bedtime']
    assert_equal 'abc', json_response['data']['photo']
    assert_equal false, json_response['data']['cool']
  end
end

class Api::V2::BooksControllerTest < ActionController::TestCase
  def after_teardown
    Api::V2::BookResource.paginator :offset
  end

  def test_books_offset_pagination_no_params
    Api::V2::BookResource.paginator :offset

    get :index
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['title']
  end

  def test_books_offset_pagination
    Api::V2::BookResource.paginator :offset

    get :index, {page: {offset: 50, limit: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['title']
  end

  def test_books_offset_pagination_bad_page_param
    Api::V2::BookResource.paginator :offset

    get :index, {page: {offset_bad: 50, limit: 12}}
    assert_response :bad_request
    assert_match /offset_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :offset

    get :index, {page: {offset: 50, limit: 1000}}
    assert_response :bad_request
    assert_match /Limit exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :offset

    get :index, {page: {offset: 50, limit: -1}}
    assert_response :bad_request
    assert_match /-1 is not a valid value for limit page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_invalid_page_format
    Api::V2::BookResource.paginator :offset

    get :index, {page: 50}
    assert_response :bad_request
    assert_match /Invalid Page Object./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_no_params
    Api::V2::BookResource.paginator :paged

    get :index
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['title']
  end

  def test_books_paged_pagination_no_page
    Api::V2::BookResource.paginator :paged

    get :index, {page: {size: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['title']
  end

  def test_books_paged_pagination
    Api::V2::BookResource.paginator :paged

    get :index, {page: {number: 3, size: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 24', json_response['data'][0]['title']
  end

  def test_books_paged_pagination_bad_page_param
    Api::V2::BookResource.paginator :paged

    get :index, {page: {number_bad: 50, size: 12}}
    assert_response :bad_request
    assert_match /number_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :paged

    get :index, {page: {number: 50, size: 1000}}
    assert_response :bad_request
    assert_match /size exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :paged

    get :index, {page: {number: 50, size: -1}}
    assert_response :bad_request
    assert_match /-1 is not a valid value for size page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_invalid_page_format_interpret_int_text
    Api::V2::BookResource.paginator :paged

    get :index, {page: 'qwerty'}
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['title']
  end

  def test_books_paged_pagination_invalid_page_format_interpret_int
    Api::V2::BookResource.paginator :paged

    get :index, {page: 3}
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 20', json_response['data'][0]['title']
  end
end
