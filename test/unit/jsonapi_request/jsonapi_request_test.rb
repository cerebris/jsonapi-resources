require File.expand_path('../../../test_helper', __FILE__)

class JSONAPIRequestTest < ActiveSupport::TestCase
  def test_parse_includes_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso_currency'
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    assert request.errors.empty?
  end

  def test_parse_dasherized_with_dasherized_include
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso-currency'
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

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

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    refute request.errors.empty?
    assert_equal 'iso_currency is not a valid association of expense-entries', request.errors[0].detail
  end

  def test_parse_fields_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {expense_entries: 'iso_currency'}
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

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

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

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

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    refute request.errors.empty?
    assert_equal 'iso_currency is not a valid field for expense-entries.', request.errors[0].detail
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

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    refute request.errors.empty?
    assert_equal 'expense_entries is not a valid resource.', request.errors[0].detail
  end
end
