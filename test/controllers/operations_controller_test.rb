require File.expand_path('../../test_helper', __FILE__)

def set_operations_content_type_header!
  @request.headers['Content-Type'] = JSONAPI::OPERATIONS_MEDIA_TYPE
end

class PostsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
    JSONAPI.configuration.json_key_format = :dasherized_key
  end

  def test_index
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'include' => ['comments']
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'filter' => { 'id' => '1,2' },
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert json_response['operations'][0]['data'].size > 2
    assert_equal 2, json_response['operations'][1]['data'].size
  end

  def test_get_relationship_to_one
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '2',
                    'relationship' => 'comments'
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][0]['data'][0].key?('type')
    assert json_response['operations'][0]['data'][0].key?('id')
    assert_equal 'comments', json_response['operations'][0]['data'][0]['type']
    assert_equal '3', json_response['operations'][0]['data'][0]['id']
    assert json_response['operations'][0]['data'][0]['attributes'].key?('body')
  end

  def test_get_relationship_to_many
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '2',
                    'relationship' => 'author'

                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][0]['data'].key?('type')
    assert json_response['operations'][0]['data'].key?('id')
    assert_equal 'people', json_response['operations'][0]['data']['type']
    assert_equal '1', json_response['operations'][0]['data']['id']
  end

  def test_index_incorrect_content_type
    @request.headers['Content-Type'] = JSONAPI::MEDIA_TYPE

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'include' => ['comments']
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'filter' => { 'id' => '1,2' },
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response 415
    assert json_response.is_a?(Hash)
    assert_equal 'Unsupported media type', json_response['errors'][0]['title']
  end

  def test_show
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '1'
                },
                'params' => {
                    'include' => ['comments']
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '2'
                },
                'params' => {
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'posts', json_response['operations'][0]['data']['type']
    assert_equal '1', json_response['operations'][0]['data']['id']
    assert_equal 'posts', json_response['operations'][1]['data']['type']
    assert_equal '2', json_response['operations'][1]['data']['id']
  end

  def test_add
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'posts'
                },
                'data' => {
                    'type' => 'posts',
                    'attributes' => {
                        'title' => 'Foobar GEM is the bomb',
                        'body' => 'Foobar will make your app go boom!!'
                    },
                    'relationships' => {
                        'author' => { 'data' => { 'type' => 'people', 'id' => '3' } }
                    }
                }
            },
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'posts'
                },
                'data' => {
                    'type' => 'posts',
                    'attributes' => {
                        'title' => 'Foobar GEM - maybe not',
                        'body' => "Foobar doesn't seem production ready. Seems to publish your users' passwords to a Canadian server."
                    },
                    'relationships' => {
                        'author' => { 'data' => { 'type' => 'people', 'id' => '3' } }
                    }
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'Foobar GEM is the bomb', json_response['operations'][0]['data']['attributes']['title']
    assert_equal 'Foobar GEM - maybe not', json_response['operations'][1]['data']['attributes']['title']
  end

  def test_add_to_one
    set_operations_content_type_header!

    ruby = Section.find_by(name: 'ruby')

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'posts',
                    'id' => '20',
                    'relationship' => 'section'
                },
                'data' => { 'type' => 'sections', 'id' => "#{ruby.id}" }
            }
        ]
    }
    assert_response :success

    post_object = Post.find(20)
    assert_equal ruby.id, post_object.section_id

    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
  end

  def test_add_to_many
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'posts',
                    'id' => '20',
                    'relationship' => 'tags'
                },
                'data' => [{ 'type' => 'tags', 'id' => 3 }, { 'type' => 'tags', 'id' => 4 }]
            }
        ]
    }
    assert_response :success

    post_object = Post.find(20)
    assert_equal [3, 4], post_object.tag_ids

    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
  end

  def test_remove
    set_operations_content_type_header!

    initial_count = Post.count

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'remove',
                'ref' => {
                    'type' => 'posts',
                    'id' => '18'
                }
            }
        ]
    }

    assert_response :success
    assert_equal initial_count - 1, Post.count
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
  end

  def test_remove_has_one
    set_operations_content_type_header!

    post_object = Post.find(19)
    post_object.section_id = '1'
    post_object.save!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'remove',
                'ref' => {
                    'type' => 'posts',
                    'id' => '19',
                    'relationship' => 'section'
                }
            }
        ]
    }

    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)

    post_object = Post.find(19)
    assert_nil post_object.section_id
  end

  def test_remove_has_many
    set_operations_content_type_header!

    post_object = Post.find(19)
    post_object.tag_ids = ['1', '4']
    post_object.save!

    post_object = Post.find(19)
    assert_equal [1, 4], post_object.tag_ids

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'remove',
                'ref' => {
                    'type' => 'posts',
                    'id' => '19',
                    'relationship' => 'tags'
                },
                'data' => [{ 'type' => 'tags', 'id' => '4' }]
            }
        ]
    }

    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)

    post_object = Post.find(19)
    assert_equal [1], post_object.tag_ids
  end

  def test_replace
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'replace',
                'ref' => {
                    'type' => 'posts',
                    'id' => '20'
                },
                'data' => {
                    'type' => 'posts',
                    'attributes' => {
                        'title' => 'Update 20',
                        'body' => 'Post 20 - Boo-yeah'
                    }
                }
            },
            {
                'op' => 'replace',
                'ref' => {
                    'type' => 'posts',
                    'id' => '19',
                    'relationship' => 'section'
                },
                'data' => { 'type' => 'sections', 'id' => '4' }

            },
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'Update 20', json_response['operations'][0]['data']['attributes']['title']
    assert_empty json_response['operations'][1]
  end

  def test_index_fields
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'filter' => { 'id' => '1,2' },
                    'include' => ['comments'],
                    'fields' => { 'posts' => ['title', 'author'] }
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
    assert_equal 'posts', json_response['operations'][0]['data'][0]['type']
    assert_equal '1', json_response['operations'][0]['data'][0]['id']
    assert_equal 'posts', json_response['operations'][0]['data'][1]['type']
    assert_equal '2', json_response['operations'][0]['data'][1]['id']
    assert_equal 'New post', json_response['operations'][0]['data'][0]['attributes']['title']
    assert_equal 'http://test.host/posts/1/relationships/author', json_response['operations'][0]['data'][0]['relationships']['author']['links']['self']
    assert_nil json_response['operations'][0]['data'][0]['attributes']['body']
    assert_nil json_response['operations'][0]['data'][0]['relationships']['tags']
  end

  def test_index_sort
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'include' => ['comments'],
                    'sort' => ['title']
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'include' => ['comments'],
                    'sort' => ['-title']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'A', json_response['operations'][0]['data'][0]['attributes']['title'][0, 1]
    assert_equal 'U', json_response['operations'][0]['data'][19]['attributes']['title'][0, 1]
    assert_equal 'U', json_response['operations'][1]['data'][0]['attributes']['title'][0, 1]
    assert_equal 'A', json_response['operations'][1]['data'][19]['attributes']['title'][0, 1]
  end

  def test_pointer_ref
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => { 'pointer' => '/0/data/1/type' },
                    'id' => { 'pointer' => '/0/data/1/id' }

                },
                'params' => {
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'posts', json_response['operations'][0]['data'][1]['type']
    assert_equal '2', json_response['operations'][0]['data'][1]['id']
    assert_equal 'posts', json_response['operations'][1]['data']['type']
    assert_equal '2', json_response['operations'][1]['data']['id']
  end

  def test_pointer_to_hash
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => { 'pointer' => '/0' },
                    'id' => { 'pointer' => '/0/data/1/id' }

                },
                'params' => {
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response 400
    assert_equal 'Invalid pointer resolution', json_response['errors'][0]['title']
  end

  def test_pointer_ref_bad_hash
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => { 'punter' => '/0/data/0/type' },
                    'id' => { 'punter' => '/0/data/1/id' }

                },
                'params' => {
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response 400
    assert_equal 'Invalid pointer', json_response['errors'][0]['title']
  end

  def test_pointer_ref_bad_array
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => ['foo'],
                    'id' => { 'pointer' => '/0/data/1/id' }
                },
                'params' => {
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response 400
    assert_equal 'Invalid pointer', json_response['errors'][0]['title']
  end

  def test_bad_op
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'getty',
                'ref' => {
                    'type' => 'posts'
                }
            }
        ]
    }
    assert_response 400
    assert_equal 'Invalid op', json_response['errors'][0]['title']
  end

  def test_bad_operations_key
    set_operations_content_type_header!

    patch :operations, params: {
        ops: {
            'op' => 'get',
            'ref' => {
                'type' => 'posts'
            }
        }
    }
    assert_response 400
    assert_equal 'Missing Parameter', json_response['errors'][0]['title']
    assert_equal '/', json_response['errors'][0]['source']['pointer']
  end

  def test_errors_goto_top_level
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '2',
                    'relationship' => 'author'

                }
            },
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts',
                    'id' => '24589752',
                    'relationship' => 'author'

                }
            }
        ]
    }
    assert_response 400
    assert_equal 'Record not found', json_response['errors'][0]['title']
    assert_equal 'The record identified by 24589752 could not be found.', json_response['errors'][0]['detail']
    assert_equal '404', json_response['errors'][0]['code']
    assert_equal '/operations/1', json_response['errors'][0]['source']['pointer']
  end

  def test_related_add
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'people'
                },
                'data' => {
                    'type' => 'people',
                    'attributes' => {
                        'name' => 'Brand new author',
                        'email' => 'sjasd@email.zzz',
                        'date-joined' => DateTime.parse('2017-1-1 4:20:00 UTC +00:00')
                    }
                }
            },
            {
                'op' => 'add',
                'ref' => {
                    'type' => 'posts'
                },
                'data' => {
                    'type' => 'posts',
                    'attributes' => {
                        'title' => 'JR: now with related object creates',
                        'body' => 'The author of this request was submitted with this post. Exciting, I know!'
                    },
                    'relationships' => {
                        'author' => {
                            'data' => {
                                'type' => 'people',
                                'id' =>  {
                                    'pointer' => '/0/data/id'
                                }
                            }
                        }
                    }
                },
                'params' => {
                    'include' => ['author']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 2
    assert json_response['operations'][0].is_a?(Hash)
    assert json_response['operations'][1].is_a?(Hash)
    assert_equal 'JR: now with related object creates', json_response['operations'][1]['data']['attributes']['title']
    assert_equal '6', json_response['operations'][0]['data']['id']
    assert_equal json_response['operations'][1]['data']['relationships']['author']['data']['id'],
                 json_response['operations'][0]['data']['id']
  end
end

class Api::V1::PostsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
  end

  def test_index_namespaced
    set_operations_content_type_header!

    patch :operations, params: {
        'operations' => [
            {
                'op' => 'get',
                'ref' => {
                    'type' => 'posts'
                },
                'params' => {
                    'filter' => { 'id' => '1,2' },
                    'sort' => ['id'],
                    'include' => ['comments']
                }
            }
        ]
    }
    assert_response :success
    assert json_response.is_a?(Hash)
    assert json_response['operations'].is_a?(Array)
    assert_equal json_response['operations'].length, 1
    assert json_response['operations'][0].is_a?(Hash)
    assert_equal 'posts', json_response['operations'][0]['data'][0]['type']
    assert_equal '1', json_response['operations'][0]['data'][0]['id']
    assert_equal 'posts', json_response['operations'][0]['data'][1]['type']
    assert_equal '2', json_response['operations'][0]['data'][1]['id']
    assert_equal 'New post', json_response['operations'][0]['data'][0]['attributes']['title']
    assert_equal 'http://test.host/api/v1/posts/1/relationships/writer', json_response['operations'][0]['data'][0]['relationships']['writer']['links']['self']
  end
end
