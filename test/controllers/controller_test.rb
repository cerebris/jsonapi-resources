require File.expand_path('../../test_helper', __FILE__)
require File.expand_path('../../fixtures/active_record', __FILE__)

class PostsControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_response :success
  end

  def test_index_filter_by_id
    get :index, {id: '1'}
    assert_response :success
  end

  def test_index_filter_by_title
    get :index, {title: 'New post'}
    assert_response :success
  end

  def test_index_filter_by_ids
    get :index, {ids: '1,2'}
    assert_response :success
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
    assert_response :not_found
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
    assert_response :not_found
    assert_match /posters is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_on_association
    get :index, {author: '1'}
    assert_response :success
    assert_equal 1, json_response['posts'].size
  end

  # ToDo: test validating the parameter values
  # def test_index_invalid_filter_value
  #   get :index, {ids: [1,'asdfg1']}
  #   assert_response :bad_request
  # end

  def test_show_single
    get :show, {id: '1'}
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 'New post', json_response['posts'][0]['title']
    assert_equal 'A body!!!', json_response['posts'][0]['body']
    assert_equal [1,2,3], json_response['posts'][0]['links']['tags']
    assert_equal [1,2], json_response['posts'][0]['links']['comments']
    assert_nil json_response['linked']
  end

  def test_show_single_with_includes
    get :show, {id: '1', include: 'comments'}
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 'New post', json_response['posts'][0]['title']
    assert_equal 'A body!!!', json_response['posts'][0]['body']
    assert_equal [1,2,3], json_response['posts'][0]['links']['tags']
    assert_equal [1,2], json_response['posts'][0]['links']['comments']
    assert_equal 2, json_response['linked']['comments'].size
    assert_nil json_response['linked']['tags']
  end

  def test_show_single_with_fields
    get :show, {id: '1', fields: 'author'}
    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_nil json_response['posts'][0]['title']
    assert_nil json_response['posts'][0]['body']
    assert_equal 1, json_response['posts'][0]['links']['author']
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
    post :create, { posts: {
                      title: 'JAR is Great',
                      body:  'JSON API Resources is the greatest thing since unsliced bread.',
                      links: {
                        author: 3
                      }
                    }
                  }

    assert_response :created
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'JAR is Great', json_response['posts'][0]['title']
    assert_equal 'JSON API Resources is the greatest thing since unsliced bread.', json_response['posts'][0]['body']
  end

  def test_create_simple_unpermitted_attributes
    post :create, { posts: {
        subject: 'JAR is Great',
        body:  'JSON API Resources is the greatest thing since unsliced bread.',
        links: {
            author: 3
        }
      }
    }

    assert_response :bad_request
    assert_match /subject/, json_response['errors'][0]['detail']
  end

  def test_create_with_links
    post :create, { posts: {
                      title: 'JAR is Great',
                      body:  'JSON API Resources is the greatest thing since unsliced bread.',
                      links: {
                        author: 3,
                        tags: [1,2]
                      }
                    }
                  }

    assert_response :created
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'JAR is Great', json_response['posts'][0]['title']
    assert_equal 'JSON API Resources is the greatest thing since unsliced bread.', json_response['posts'][0]['body']
    assert_equal [1,2], json_response['posts'][0]['links']['tags']
  end

  def test_create_with_links_include_and_fields
    post :create, { posts: {
        title: 'JAR is Great!',
        body:  'JSON API Resources is the greatest thing since unsliced bread!',
        links: {
            author: 3,
            tags: [1,2]
        }
      },
      include: 'author,author.posts',
      fields: 'id,title,author'
    }

    assert_response :created
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal 'JAR is Great!', json_response['posts'][0]['title']
    assert_equal nil, json_response['posts'][0]['body']
    assert_equal nil, json_response['posts'][0]['links']['tags']
    assert_not_nil json_response['linked']['posts']
    assert_not_nil json_response['linked']['people']
    assert_nil json_response['linked']['tags']
  end

  def test_update_with_links
    javascript = Section.find_by(name: 'javascript')

    post :update, {id: 3, posts: {
        title: 'A great new Post',
        links: {
            section: javascript.id,
            tags: [3,4]
        }
      }
    }

    assert_response :success
    assert_equal 1, json_response['posts'].size
    assert_equal 3, json_response['posts'][0]['links']['author']
    assert_equal  javascript.id, json_response['posts'][0]['links']['section']
    assert_equal 'A great new Post', json_response['posts'][0]['title']
    assert_equal 'AAAA', json_response['posts'][0]['body']
    assert_equal [3,4], json_response['posts'][0]['links']['tags']
  end

  def test_update_unpermitted_attributes
    post :update, {id: 3, posts: {
        subject: 'A great new Post',
        links: {
            author: 1,
            tags: [3,4]
        }
      }
    }

    assert_response :bad_request
    assert_match /author/, json_response['errors'][0]['detail']
    assert_match /subject/, json_response['errors'][0]['detail']
  end

  def test_update_bad_attributes
    post :update, {id: 3, posts: {
        subject: 'A great new Post',
        linked_objects: {
            author: 1,
            tags: [3,4]
        }
    }
    }

    assert_response :bad_request
  end

  def test_delete_single
    initial_count = Post.count
    post :destroy, {id: '4'}
    assert_response :no_content
    assert_equal initial_count - 1, Post.count
  end

  def test_delete_multiple
    initial_count = Post.count
    post :destroy, {id: '5,6'}
    assert_response :no_content
    assert_equal initial_count - 2, Post.count
  end

  def test_delete_multiple_one_does_not_exist
    initial_count = Post.count
    post :destroy, {id: '5,6,99999'}
    assert_response :not_found
    assert_equal initial_count, Post.count
  end
end

class TagsControllerTest < ActionController::TestCase
  def test_tags_index
    get :index, {ids: '6,7,8,9', include: 'posts,posts.tags,posts.author.posts'}
    assert_response :success
    assert_equal 4, json_response['tags'].size
    assert_equal 2, json_response['linked']['posts'].size
  end
end

class ExpenseEntriesControllerTest < ActionController::TestCase
  def test_expense_entries_index
    get :index
    assert_response :success
    assert_equal 2, json_response['expense_entries'].size
  end
end

class CurrenciesControllerTest < ActionController::TestCase
  def test_currencies_index
    get :index
    assert_response :success
    assert_equal 2, json_response['currencies'].size
  end

  def test_currencies_show
    get :show, {code: 'USD', include: 'expense_entries,expense_entries.currency_codes'}
    assert_response :success
    assert_equal 1, json_response['currencies'].size
    assert_equal 2, json_response['linked']['expense_entries'].size
  end

end

class PeopleControllerTest < ActionController::TestCase
  def test_create_validations
    post :create, { people: {
        name: 'Steve Jobs',
        email:  'sj@email.zzz',
        date_joined: DateTime.parse('2014-1-30 4:20:00 UTC +00:00')
      }
    }

    assert_response :success
  end

  def test_create_validations_missing_attribute
    post :create, { people: {
        email:  'sj@email.zzz'
      }
    }

    assert_response :bad_request
    assert_equal 2, json_response['errors'].size
    assert_equal JSON::API::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_equal JSON::API::VALIDATION_ERROR, json_response['errors'][1]['code']
    assert_match /date_joined - can't be blank/, response.body
    assert_match /name - can't be blank/, response.body
  end
end

class AuthorControllerTest < ActionController::TestCase
  def test_get_person_as_author
    get :index, {id: '1'}
    assert_response :success
    assert_equal 1, json_response['authors'].size
    assert_equal 1, json_response['authors'][0]['id']
    assert_equal 'Joe Author', json_response['authors'][0]['name']
    assert_equal nil, json_response['authors'][0]['email']
    assert_equal 1, json_response['authors'][0]['links'].size
    assert_equal 2, json_response['authors'][0]['links']['posts'].size
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
    assert_equal 2, json_response['authors'][0]['links']['posts'].size
  end
end
