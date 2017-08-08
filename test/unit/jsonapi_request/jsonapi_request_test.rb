require File.expand_path('../../../test_helper', __FILE__)

class CatResource < JSONAPI::Resource
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'

  filters :name

  def self.sortable_fields(context)
    super(context) << :"mother.name"
  end
end

class TreeResource < JSONAPI::Resource
  def self.sortable_field?(key, context)
    key =~ /^sort\d+/
  end
end

class JSONAPIRequestTest < ActiveSupport::TestCase
  def test_parse_includes_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso_currency'
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    assert request.errors.empty?
  end

  def test_parse_blank_includes
    include_directives = JSONAPI::RequestParser.new.parse_include_directives(nil, '')
    assert_empty include_directives.model_includes
  end

  def test_parse_dasherized_with_dasherized_include
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso-currency'
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_underscored_include
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso_currency'
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    refute request.errors.empty?
    assert_equal 'iso_currency is not a valid includable relationship of expense-entries', request.errors[0].detail
  end

  def test_parse_fields_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {expense_entries: 'iso_currency'}
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    request.parse_fields(ExpenseEntryResource, params[:fields])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_dasherized_fields
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense-entries' => 'iso-currency'
        }
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_fields(ExpenseEntryResource, params[:fields])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_underscored_fields
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense-entries' => 'iso_currency'
        }
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    e = assert_raises JSONAPI::Exceptions::InvalidField do
      request.parse_fields(ExpenseEntryResource, params[:fields])
    end
    refute e.errors.empty?
    assert_equal 'iso_currency is not a valid field for expense-entries.', e.errors[0].detail
  end

  def test_parse_dasherized_with_underscored_resource
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense_entries' => 'iso-currency'
        }
      }
    )

    request = JSONAPI::RequestParser.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )
    e = assert_raises JSONAPI::Exceptions::InvalidResource do
      request.parse_fields(ExpenseEntryResource, params[:fields])
    end
    refute e.errors.empty?
    assert_equal 'expense_entries is not a valid resource.', e.errors[0].detail
  end

  def test_parse_filters_with_valid_filters
    setup_request
    filters = @request.parse_filters(CatResource, {name: 'Whiskers'})
    assert_equal(filters[:name], 'Whiskers')
    assert_equal(@request.errors, [])
  end

  def test_parse_filters_with_non_valid_filter
    setup_request
    e = assert_raises JSONAPI::Exceptions::FilterNotAllowed do
        @request.parse_filters(CatResource, {breed: 'Whiskers'}) # breed is not a set filter
    end
    assert_equal 'breed is not allowed.', e.errors[0].detail
  end

  def test_parse_filters_with_no_filters
    setup_request
    filters = @request.parse_filters(CatResource, nil)
    assert_equal(filters, {})
    assert_equal(@request.errors, [])
  end

  def test_parse_filters_with_invalid_filters_param
    setup_request
    filters = @request.parse_filters(CatResource, 'noeach') # String does not implement #each
    assert_equal(filters, {})
    assert_equal(@request.errors.count, 1)
    assert_equal(@request.errors.first.title, "Invalid filters syntax")
  end

  def test_parse_sort_with_valid_sorts
    setup_request
    sort_criteria = @request.parse_sort_criteria(CatResource, "-name")
    assert_equal(@request.errors, [])
    assert_equal(sort_criteria, [{:field=>"name", :direction=>:desc}])
  end

  def test_parse_sort_with_resource_validated_sorts
    setup_request
    e = assert_raises JSONAPI::Exceptions::InvalidSortCriteria do
      @request.parse_sort_criteria(TreeResource, "sort66,name")
    end
    assert_equal 'name is not a valid sort criteria for trees', e.errors[0].detail
  end

  def test_parse_sort_with_relationships
    setup_request
    sort_criteria = @request.parse_sort_criteria(CatResource, "-mother.name")
    assert_equal(@request.errors, [])
    assert_equal(sort_criteria, [{:field=>"mother.name", :direction=>:desc}])
  end

  private

  def setup_request
    @request = JSONAPI::RequestParser.new
  end
end
