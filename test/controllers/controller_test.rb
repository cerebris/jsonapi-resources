require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/active_record', __FILE__)

class PostsControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_response :success
    assert json_response['posts'].is_a?(Array)
  end

  def test_index_filter_by_id
    get :index, {id: '1'}
    assert_response :success
    assert json_response['posts'].is_a?(Array)
  end

  def test_index_filter_by_title
    get :index, {title: 'New post'}
    assert_response :success
    assert json_response['posts'].is_a?(Array)
  end

  def test_index_filter_by_ids
    get :index, {ids: '1,2'}
    assert_response :success
    assert json_response['posts'].is_a?(Array)
    assert_equal 2, json_response['posts'].size
  end

  def test_index_filter_by_ids_and_include_related
    get :index, ids: '2', include: 'comments'
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 1, json_response['linked']['comments'].size
  end

  def test_index_filter_by_ids_and_include_related_different_type
    get :index, {ids: '1,2', include: 'author'}
    assert_response :success
    assert_equal 2, json_response['posts'].size
    assert_equal 1, json_response['linked']['people'].size
  end

  def test_index_filter_by_ids_and_fields
    get :index, {ids: '1,2', 'fields' => 'id,title,author'}
    assert_response :success
    assert_equal 2, json_response['posts'].size

    # id, title, links
    assert_equal 3, json_response['posts'][0].size
    assert json_response['posts'][0].has_key?('id')
    assert json_response['posts'][0].has_key?('title')
    assert json_response['posts'][0].has_key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_type
    get :index, {ids: '1,2', 'fields' => {'posts' => 'id,title,author'}}
    assert_response :success
    assert_equal 2, json_response['posts'].size

    # id, title, links
    assert_equal 3, json_response['posts'][0].size
    assert json_response['posts'][0].has_key?('id')
    assert json_response['posts'][0].has_key?('title')
    assert json_response['posts'][0].has_key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_unrelated_type
    get :index, {ids: '1,2', 'fields' => {'currencies' => 'code'}}
    assert_response :bad_request
    assert_match /currencies is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_by_ids_and_fields_2
    get :index, {ids: '1,2', 'fields' => 'author'}
    assert_response :success
    assert_equal 2, json_response['posts'].size

    # links
    assert_equal 1, json_response['posts'][0].size
    assert json_response['posts'][0].has_key?('links')
  end

  def test_filter_association_single
    get :index, {tags: '5,1'}
    assert_response :success
    assert_equal 3, json_response['posts'].size
    assert_match /New post/, response.body
    assert_match /JR Solves your serialization woes!/, response.body
    assert_match /JR How To/, response.body
  end

  def test_filter_associations_multiple
    get :index, {tags: '5,1', comments: '3'}
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_match /JR Solves your serialization woes!/, response.body
  end

  def test_filter_associations_multiple_not_found
    get :index, {tags: '1', comments: '3'}
    assert_response :success
    assert_equal 0, json_response.size
  end

  def test_bad_filter
    get :index, {post_ids: '1,2'}
    assert_response :bad_request
    assert_match /post_ids is not allowed/, response.body
  end

  def test_bad_filter_value_not_integer_array
    get :index, {ids: 'asdfg'}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_integer
    get :index, {id: 'asdfg'}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_found_array
    get :index, {ids: '5412333'}
    assert_response :not_found
    assert_match /5412333 could not be found/, response.body
  end

  def test_bad_filter_value_not_found
    get :index, {id: '5412333'}
    assert_response :not_found
    assert_match /5412333 could not be found/, json_response['errors'][0]['detail']
  end

  def test_index_malformed_fields
    get :index, {ids: '1,2', 'fields' => 'posts'}
    assert_response :bad_request
    assert_match /posts is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_field_not_supported
    get :index, {ids: '1,2', 'fields' => {'posts' => 'id,title,rank,author'}}
    assert_response :bad_request
    assert_match /rank is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_resource_not_supported
    get :index, {ids: '1,2', 'fields' => {'posters' => 'id,title'}}
    assert_response :bad_request
    assert_match /posters is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_on_association
    get :index, {author: '1'}
    assert_response :success
    assert_equal 3, json_response['posts'].size
  end

  # ToDo: test validating the parameter values
  # def test_index_invalid_filter_value
  #   get :index, {ids: [1,'asdfg1']}
  #   assert_response :bad_request
  # end

  def test_show_single
    get :show, {id: '1'}
    assert_response :success
    assert json_response['posts'].is_a?(Hash)
    assert_equal 'New post', json_response['posts']['title']
    assert_equal 'A body!!!', json_response['posts']['body']
    assert_equal [1, 2, 3], json_response['posts']['links']['tags']
    assert_equal [1, 2], json_response['posts']['links']['comments']
    assert_nil json_response['linked']
  end

  def test_show_single_with_includes
    get :show, {id: '1', include: 'comments'}
    assert_response :success
    assert json_response['posts'].is_a?(Hash)
    assert_equal 'New post', json_response['posts']['title']
    assert_equal 'A body!!!', json_response['posts']['body']
    assert_equal [1, 2, 3], json_response['posts']['links']['tags']
    assert_equal [1, 2], json_response['posts']['links']['comments']
    assert_equal 2, json_response['linked']['comments'].size
    assert_nil json_response['linked']['tags']
  end

  def test_show_single_with_fields
    get :show, {id: '1', fields: 'author'}
    assert_response :success
    assert json_response['posts'].is_a?(Hash)
    assert_nil json_response['posts']['title']
    assert_nil json_response['posts']['body']
    assert_equal 1, json_response['posts']['links']['author']
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
    post :create,
         {
           posts: {
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 3
             }
           }
         }

    assert_response :created
    assert json_response['posts'].is_a?(Hash)
    assert_equal 3, json_response['posts']['links']['author']
    assert_equal 'JR is Great', json_response['posts']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['posts']['body']
  end

  def test_create_link_to_missing_object
    post :create,
         {
           posts: {
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 304567
             }
           }
         }

    assert_response :bad_request
    # Todo: check if this validation is working
    assert_match /author - can't be blank/, response.body
  end

  def test_create_extra_param
    post :create,
         {
           posts: {
             asdfg: 'aaaa',
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 3
             }
           }
         }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_create_multiple
    post :create,
         {
           posts: [
             {
               title: 'JR is Great',
               body: 'JSONAPIResources is the greatest thing since unsliced bread.',
               links: {
                 author: 3
               }
             },
             {
               title: 'Ember is Great',
               body: 'Ember is the greatest thing since unsliced bread.',
               links: {
                 author: 3
               }
             }
           ]
         }

    assert_response :created
    assert json_response['posts'].is_a?(Array)
    assert_equal json_response['posts'].size, 2
    assert_equal json_response['posts'][0]['links']['author'], 3
    assert_match /JR is Great/, response.body
    assert_match /Ember is Great/, response.body
  end

  def test_create_multiple_wrong_case
    post :create,
         {
           posts: [
             {
               Title: 'JR is Great',
               body: 'JSONAPIResources is the greatest thing since unsliced bread.',
               links: {
                 author: 3
               }
             },
             {
               title: 'Ember is Great',
               BODY: 'Ember is the greatest thing since unsliced bread.',
               links: {
                 author: 3
               }
             }
           ]
         }

    assert_response :bad_request
    assert_match /Title/, json_response['errors'][0]['detail']
  end

  def test_create_simple_missing_posts
    post :create,
         {
           posts_spelled_wrong: {
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 3
             }
           }
         }

    assert_response :bad_request
    assert_match /The required parameter, posts, is missing./, json_response['errors'][0]['detail']
  end

  def test_create_simple_unpermitted_attributes
    post :create,
         {
           posts: {
             subject: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 3
             }
           }
         }

    assert_response :bad_request
    assert_match /subject/, json_response['errors'][0]['detail']
  end

  def test_create_with_links
    post :create,
         {
           posts: {
             title: 'JR is Great',
             body: 'JSONAPIResources is the greatest thing since unsliced bread.',
             links: {
               author: 3,
               tags: [3, 4]
             }
           }
         }

    assert_response :created
    assert json_response['posts'].is_a?(Hash)
    assert_equal 3, json_response['posts']['links']['author']
    assert_equal 'JR is Great', json_response['posts']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['posts']['body']
    assert_equal [3, 4], json_response['posts']['links']['tags']
  end

  def test_create_with_links_include_and_fields
    post :create,
         {
           posts: {
             title: 'JR is Great!',
             body: 'JSONAPIResources is the greatest thing since unsliced bread!',
             links: {
               author: 3,
               tags: [3, 4]
             }
           },
           include: 'author,author.posts',
           fields: 'id,title,author'
         }

    assert_response :created
    assert json_response['posts'].is_a?(Hash)
    assert_equal 3, json_response['posts']['links']['author']
    assert_equal 'JR is Great!', json_response['posts']['title']
    assert_equal nil, json_response['posts']['body']
    assert_equal nil, json_response['posts']['links']['tags']
    assert_not_nil json_response['linked']['posts']
    assert_not_nil json_response['linked']['people']
    assert_nil json_response['linked']['tags']
  end

  def test_update_with_links
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          posts: {
            title: 'A great new Post',
            links: {
              section: javascript.id,
              tags: [3, 4]
            }
          }
        }

    assert_response :success
    assert json_response['posts'].is_a?(Hash)
    assert_equal 3, json_response['posts']['links']['author']
    assert_equal javascript.id, json_response['posts']['links']['section']
    assert_equal 'A great new Post', json_response['posts']['title']
    assert_equal 'AAAA', json_response['posts']['body']
    assert matches_array?([3, 4], json_response['posts']['links']['tags'])
  end

  def test_update_remove_links
    put :update,
        {
          id: 3,
          posts: {
            title: 'A great new Post',
            links: {
              section: nil,
              tags: []
            }
          }
        }

    assert_response :success
    assert json_response['posts'].is_a?(Hash)
    assert_equal 3, json_response['posts']['links']['author']
    assert_equal nil, json_response['posts']['links']['section']
    assert_equal 'A great new Post', json_response['posts']['title']
    assert_equal 'AAAA', json_response['posts']['body']
    assert matches_array?([], json_response['posts']['links']['tags'])
  end

  def test_update_relationship_has_one
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    assert_not_equal ruby.id, post_object.section_id

    put :update_association, {post_id: 3, association: 'section', sections: ruby.id}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_update_relationship_has_one_singular_param
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)

    put :update_association, {post_id: 3, association: 'section', section: ruby.id}

    assert_response :bad_request
  end

  def test_update_relationship_has_one_singular_param_relation_nil
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = nil
    post_object.save!

    put :update_association, {post_id: 3, association: 'section', sections: ruby.id}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_create_relationship_has_one_singular_param_relation_nil
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = nil
    post_object.save!

    post :create_association, {post_id: 3, association: 'section', sections: ruby.id}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_create_relationship_has_one_singular_param_relation_not_nil
    ruby = Section.find_by(name: 'ruby')
    js = Section.find_by(name: 'javascript')
    post_object = Post.find(3)
    post_object.section_id = js.id
    post_object.save!

    post :create_association, {post_id: 3, association: 'section', sections: ruby.id}

    assert_response :bad_request
    assert_match /The relation already exists./, response.body
    post_object = Post.find(3)
    assert_equal js.id, post_object.section_id
  end

  def test_update_relationship_has_many_join_table_single
    put :update_association, {post_id: 3, association: 'tags', tags: []}
    assert_response :no_content

    post_object = Post.find(3)
    assert_equal 0, post_object.tags.length

    put :update_association, {post_id: 3, association: 'tags', tags: [2]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 1, post_object.tags.length

    put :update_association, {post_id: 3, association: 'tags', tags: 5}

    assert_response :no_content
    post_object = Post.find(3)
    tags = post_object.tags.collect { |tag| tag.id }
    assert_equal 1, tags.length
    assert matches_array? [5], tags
  end

  def test_update_relationship_has_many_join_table
    put :update_association, {post_id: 3, association: 'tags', tags: [2, 3]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_has_many_join_table
    put :update_association, {post_id: 3, association: 'tags', tags: [2, 3]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_association, {post_id: 3, association: 'tags', tags: [5]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 3, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3, 5], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_has_many_missing_tags
    post :create_association, {post_id: 3, association: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, tags, is missing./, response.body
  end

  def test_create_relationship_has_many_join_table_record_exists
    put :update_association, {post_id: 3, association: 'tags', tags: [2, 3]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_association, {post_id: 3, association: 'tags', tags: [5, 2]}

    assert_response :bad_request
    assert_match /The relation to 2 already exists./, response.body
  end

  def test_update_relationship_has_one_mismatch_params
    post :create_association, {post_id: 3, association: 'section', authors: 1}

    assert_response :bad_request
    assert_match /The required parameter, sections, is missing./, response.body
  end

  def test_update_relationship_has_many_missing_tags
    put :update_association, {post_id: 3, association: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, tags, is missing./, response.body
  end

  def test_delete_relationship_has_one
    ruby = Section.find_by(name: 'ruby')

    post :create_association, {post_id: 9, association: 'section', sections: ruby.id}

    assert_response :no_content

    delete :destroy_association, {post_id: 9, association: 'section'}

    assert_response :no_content
    post = Post.find(9)
    assert_nil post.section
  end

  def test_delete_relationship_has_many
    put :update_association, {post_id: 9, association: 'tags', tags: [2, 3]}
    assert_response :no_content
    p = Post.find(9)
    assert_equal [2, 3], p.tag_ids

    delete :destroy_association, {post_id: 9, association: 'tags', keys: '3'}

    p.reload
    assert_response :no_content
    assert_equal [2], p.tag_ids
  end

  def test_delete_relationship_has_many_does_not_exist
    put :update_association, {post_id: 9, association: 'tags', tags: [2, 3]}
    assert_response :no_content
    p = Post.find(9)
    assert_equal [2, 3], p.tag_ids

    delete :destroy_association, {post_id: 9, association: 'tags', keys: '4'}

    p.reload
    assert_response :not_found
    assert_equal [2, 3], p.tag_ids
  end

  def test_update_mismatched_keys
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          posts: {
            id: 2,
            title: 'A great new Post',
            links: {
              section: javascript.id,
              tags: [3, 4]
            }
          }
        }

    assert_response :bad_request
    assert_match /The URL does not support the key 2/, response.body
  end

  def test_update_extra_param
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          posts: {
            asdfg: 'aaaa',
            title: 'A great new Post',
            links: {
              section: javascript.id,
              tags: [3, 4]
            }
          }
        }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_extra_param_in_links
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          posts: {
            title: 'A great new Post',
            links: {
              asdfg: 'aaaa',
              section: javascript.id,
              tags: [3, 4]
            }
          }
        }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_missing_param
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: 3,
          posts_spelled_wrong: {
            title: 'A great new Post',
            links: {
              section: javascript.id,
              tags: [3, 4]
            }
          }
        }

    assert_response :bad_request
    assert_match /The required parameter, posts, is missing./, response.body
  end

  def test_update_multiple
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          posts: [
            {
              id: 3,
              title: 'A great new Post QWERTY',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            },
            {
              id: 9,
              title: 'A great new Post ASDFG',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            }
          ]}

    assert_response :success
    assert_equal json_response['posts'].size, 2
    assert_equal json_response['posts'][0]['links']['author'], 3
    assert_equal json_response['posts'][0]['links']['section'], javascript.id
    assert_equal json_response['posts'][0]['title'], 'A great new Post QWERTY'
    assert_equal json_response['posts'][0]['body'], 'AAAA'
    assert_equal json_response['posts'][0]['links']['tags'], [3, 4]

    assert_equal json_response['posts'][1]['links']['author'], 3
    assert_equal json_response['posts'][1]['links']['section'], javascript.id
    assert_equal json_response['posts'][1]['title'], 'A great new Post ASDFG'
    assert_equal json_response['posts'][1]['body'], 'AAAA'
    assert_equal json_response['posts'][1]['links']['tags'], [3, 4]
  end

  def test_update_multiple_missing_keys
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          posts: [
            {
              title: 'A great new Post ASDFG',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            },
            {
              title: 'A great new Post QWERTY',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            }
          ]}

    assert_response :bad_request
    assert_match /A key is required/, response.body
  end

  def test_update_mismatch_keys
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9],
          posts: [
            {
              id: 3,
              title: 'A great new Post ASDFG',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            },
            {
              id: 8,
              title: 'A great new Post QWERTY',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            }
          ]}

    assert_response :bad_request
    assert_match /The URL does not support the key 8/, response.body
  end

  def test_update_multiple_count_mismatch
    javascript = Section.find_by(name: 'javascript')

    put :update,
        {
          id: [3, 9, 2],
          posts: [
            {
              id: 3,
              title: 'A great new Post QWERTY',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            },
            {
              id: 9,
              title: 'A great new Post ASDFG',
              links: {
                section: javascript.id,
                tags: [3, 4]
              }
            }
          ]}

    assert_response :bad_request
    assert_match /Count to key mismatch/, response.body
  end

  def test_update_unpermitted_attributes
    put :update,
        {
          id: 3,
          posts: {
            subject: 'A great new Post',
            links: {
              author: 1,
              tags: [3, 4]
            }
          }
        }

    assert_response :bad_request
    assert_match /author is not allowed./, response.body
    assert_match /subject is not allowed./, response.body
  end

  def test_update_bad_attributes
    put :update,
        {
          id: 3,
          posts: {
            subject: 'A great new Post',
            linked_objects: {
              author: 1,
              tags: [3, 4]
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
    assert_equal 1, json_response['author']
  end

  def test_show_has_many_relationship
    get :show_association, {post_id: '1', association: 'tags'}
    assert_response :success
    assert_equal [1, 2, 3], json_response['tags']
  end
end

class TagsControllerTest < ActionController::TestCase
  def test_tags_index
    get :index, {ids: '6,7,8,9', include: 'posts,posts.tags,posts.author.posts'}
    assert_response :success
    assert_equal 4, json_response['tags'].size
    assert_equal 2, json_response['linked']['posts'].size
  end

  def test_tags_show_multiple
    get :show, {id: '6,7,8,9'}
    assert_response :success
    assert json_response['tags'].is_a?(Array)
    assert_equal 4, json_response['tags'].size
  end

  def test_tags_show_multiple_with_include
    get :show, {id: '6,7,8,9', include: 'posts,posts.tags,posts.author.posts'}
    assert_response :success
    assert json_response['tags'].is_a?(Array)
    assert_equal 4, json_response['tags'].size
    assert_equal 2, json_response['linked']['posts'].size
  end
end

class ExpenseEntriesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_expense_entries_index
    get :index
    assert_response :success
    assert json_response['expenseEntries'].is_a?(Array)
    assert_equal 2, json_response['expenseEntries'].size
  end

  def test_expense_entries_show
    get :show, {id: 1}
    assert_response :success
    assert json_response['expenseEntries'].is_a?(Hash)
  end

  def test_expense_entries_show_include
    get :show, {id: 1, include: 'isoCurrency,employee'}
    assert_response :success
    assert json_response['expenseEntries'].is_a?(Hash)
    assert_equal 1, json_response['linked']['isoCurrencies'].size
    assert_equal 1, json_response['linked']['people'].size
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
    assert json_response['expenseEntries'].is_a?(Hash)
    assert json_response['expenseEntries'].has_key?('transactionDate')
    refute json_response['expenseEntries'].has_key?('id')
    refute json_response['expenseEntries'].has_key?('links')
    assert_equal 1, json_response['linked']['isoCurrencies'].size
    assert_equal 1, json_response['linked']['people'].size
  end

  def test_expense_entries_show_fields_type
    get :show, {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate'}}
    assert_response :success
    assert json_response['expenseEntries'].is_a?(Hash)
    assert json_response['expenseEntries'].has_key?('transactionDate')
    refute json_response['expenseEntries'].has_key?('id')
    refute json_response['expenseEntries'].has_key?('links')
    assert_equal 1, json_response['linked']['isoCurrencies'].size
    assert_equal 1, json_response['linked']['people'].size
  end

  def test_expense_entries_show_fields_type_many
    get :show, {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate',
                                                                     'isoCurrencies' => 'code,name'}}
    assert_response :success
    assert json_response['expenseEntries'].is_a?(Hash)
    assert json_response['expenseEntries'].has_key?('transactionDate')
    refute json_response['expenseEntries'].has_key?('id')
    refute json_response['expenseEntries'].has_key?('links')
    assert_equal 1, json_response['linked']['isoCurrencies'].size
    assert_equal 1, json_response['linked']['people'].size
    assert json_response['linked']['isoCurrencies'][0].has_key?('code')
    assert json_response['linked']['isoCurrencies'][0].has_key?('name')
    refute json_response['linked']['isoCurrencies'][0].has_key?('countryName')
  end

  def test_create_expense_entries_underscored
    JSONAPI.configuration.json_key_format = :underscored_key

    post :create,
         {
           expense_entries: {
             transaction_date: '2014/04/15',
             cost: 50.58,
             links: {
               employee: 3,
               iso_currency: 'USD'
             }
           },
           include: 'iso_currency',
           fields: 'id,transaction_date,iso_currency,cost,employee'
         }

    assert_response :created
    assert json_response['expense_entries'].is_a?(Hash)
    assert_equal 3, json_response['expense_entries']['links']['employee']
    assert_equal 'USD', json_response['expense_entries']['links']['iso_currency']
    assert_equal '50.58', json_response['expense_entries']['cost']

    delete :destroy, {id: json_response['expense_entries']['id']}
    assert_response :no_content
  end

  def test_create_expense_entries_camelized_key
    JSONAPI.configuration.json_key_format = :camelized_key

    post :create,
         {
           expenseEntries: {
             transactionDate: '2014/04/15',
             cost: 50.58,
             links: {
               employee: 3,
               isoCurrency: 'USD'
             }
           },
           include: 'isoCurrency',
           fields: 'id,transactionDate,isoCurrency,cost,employee'
         }

    assert_response :created
    assert json_response['expenseEntries'].is_a?(Hash)
    assert_equal 3, json_response['expenseEntries']['links']['employee']
    assert_equal 'USD', json_response['expenseEntries']['links']['isoCurrency']
    assert_equal '50.58', json_response['expenseEntries']['cost']

    delete :destroy, {id: json_response['expenseEntries']['id']}
    assert_response :no_content
  end

  def test_create_expense_entries_dasherized_key
    JSONAPI.configuration.json_key_format = :dasherized_key

    post :create,
         {
           'expense-entries' => {
             'transaction-date' => '2014/04/15',
             cost: 50.58,
             links: {
               employee: 3,
               'iso-currency' => 'USD'
             }
           },
           include: 'iso-currency',
           fields: 'id,transaction-date,iso-currency,cost,employee'
         }

    assert_response :created
    assert json_response['expense-entries'].is_a?(Hash)
    assert_equal 3, json_response['expense-entries']['links']['employee']
    assert_equal 'USD', json_response['expense-entries']['links']['iso-currency']
    assert_equal '50.58', json_response['expense-entries']['cost']

    delete :destroy, {id: json_response['expense-entries']['id']}
    assert_response :no_content
  end
end

class IsoCurrenciesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_currencies_index
    get :index
    assert_response :success
    assert_equal 2, json_response['isoCurrencies'].size
  end

  def test_currencies_json_key_underscored
    JSONAPI.configuration.json_key_format = :underscored_key
    get :index
    assert_response :success
    assert_equal 2, json_response['iso_currencies'].size
  end

  def test_currencies_json_key_dasherized
    JSONAPI.configuration.json_key_format = :dasherized_key
    get :index
    assert_response :success
    assert_equal 2, json_response['iso-currencies'].size
  end

  def test_currencies_custom_json_key
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    get :index
    assert_response :success
    assert_equal 2, json_response['IsoCurrencies'].size
  end

  def test_currencies_show
    get :show, {code: 'USD'}
    assert_response :success
    assert json_response['isoCurrencies'].is_a?(Hash)
  end
end

class PeopleControllerTest < ActionController::TestCase
  def test_create_validations
    post :create,
         {
           people: {
             name: 'Steve Jobs',
             email: 'sj@email.zzz',
             dateJoined: DateTime.parse('2014-1-30 4:20:00 UTC +00:00')
           }
         }

    assert_response :success
  end

  def test_create_validations_missing_attribute
    post :create,
         {
           people: {
             email: 'sj@email.zzz'
           }
         }

    assert_response :bad_request
    assert_equal 2, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][1]['code']
    assert_match /date_joined - can't be blank/, response.body
    assert_match /name - can't be blank/, response.body
  end

  def test_update_validations_missing_attribute
    put :update,
        {
          id: 3,
          people: {
            name: ''
          }
        }

    assert_response :bad_request
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
    get :index, {name: 'L'}
    assert_response :bad_request
  end

  def test_valid_filter_value
    get :index, {name: 'Joe Author'}
    assert_response :success
    assert_equal json_response['people'].size, 1
    assert_equal json_response['people'][0]['id'], 1
    assert_equal json_response['people'][0]['name'], 'Joe Author'
  end
end

class AuthorsControllerTest < ActionController::TestCase
  def test_get_person_as_author
    get :index, {id: '1'}
    assert_response :success
    assert_equal 1, json_response['authors'].size
    assert_equal 1, json_response['authors'][0]['id']
    assert_equal 'Joe Author', json_response['authors'][0]['name']
    assert_equal nil, json_response['authors'][0]['email']
    assert_equal 1, json_response['authors'][0]['links'].size
    assert_equal 3, json_response['authors'][0]['links']['posts'].size
  end

  def test_get_person_as_author_variable_email
    get :index, {id: '4'}
    assert_response :success
    assert_equal 1, json_response['authors'].size
    assert_equal 4, json_response['authors'][0]['id']
    assert_equal 'Tag Crazy Author', json_response['authors'][0]['name']
    assert_equal 'taggy@xyz.fake', json_response['authors'][0]['email']
    assert_equal 1, json_response['authors'][0]['links'].size
    assert_equal 2, json_response['authors'][0]['links']['posts'].size
  end

  def test_get_person_as_author_by_name_filter
    get :index, {name: 'thor'}
    assert_response :success
    assert_equal 3, json_response['authors'].size
    assert_equal 1, json_response['authors'][0]['id']
    assert_equal 'Joe Author', json_response['authors'][0]['name']
    assert_equal 1, json_response['authors'][0]['links'].size
    assert_equal 3, json_response['authors'][0]['links']['posts'].size
  end
end

class BreedsControllerTest < ActionController::TestCase
  # Note: Breed names go through the TitleValueFormatter

  def test_poro_index
    get :index
    assert_response :success
    assert_equal 0, json_response['breeds'][0]['id']
    assert_equal 'Persian', json_response['breeds'][0]['name']
  end

  def test_poro_show
    get :show, {id: '0'}
    assert_response :success
    assert json_response['breeds'].is_a?(Hash)
    assert_equal 0, json_response['breeds']['id']
    assert_equal 'Persian', json_response['breeds']['name']
  end

  def test_poro_show_multiple
    get :show, {id: '0,2'}
    assert_response :success
    assert json_response['breeds'].is_a?(Array)
    assert_equal 2, json_response['breeds'].size
    assert_equal 0, json_response['breeds'][0]['id']
    assert_equal 'Persian', json_response['breeds'][0]['name']
    assert_equal 2, json_response['breeds'][1]['id']
    assert_equal 'Sphinx', json_response['breeds'][1]['name']
  end

  def test_poro_create_simple
    post :create,
         {
           breeds: {
             name: 'tabby'
           }
         }

    assert_response :created
    assert json_response['breeds'].is_a?(Hash)
    assert_equal 'Tabby', json_response['breeds']['name']
  end

  def test_poro_create_update
    post :create,
         {
           breeds: {
             name: 'CALIC'
           }
         }

    assert_response :created
    assert json_response['breeds'].is_a?(Hash)
    assert_equal 'Calic', json_response['breeds']['name']

    put :update,
        {
          id: json_response['breeds']['id'],
          breeds: {
            name: 'calico'
          }
        }
    assert_response :success
    assert json_response['breeds'].is_a?(Hash)
    assert_equal 'Calico', json_response['breeds']['name']
  end

  def test_poro_delete
    initial_count = $breed_data.breeds.keys.count
    delete :destroy, {id: '3'}
    assert_response :no_content
    assert_equal initial_count - 1, $breed_data.breeds.keys.count
  end

end
