require File.expand_path('../../test_helper', __FILE__)

def set_content_type_header!
  @request.headers['Content-Type'] = JSONAPI::MEDIA_TYPE
end

class WidgetsControllerTest < ActionController::TestCase
  def teardown
    Widget.delete_all
    Indicator.delete_all
    Agency.delete_all
  end

  def test_fetch_widgets_sort_by_agency_name
    agency_1 = Agency.create! name: 'beta'
    agency_2 = Agency.create! name: 'alpha'
    indicator_1 = Indicator.create! import_id: 'foobar', name: 'bar', agency: agency_1
    indicator_2 = Indicator.create! import_id: 'foobar2', name: 'foo', agency: agency_2
    Widget.create! name: 'bar', indicator: indicator_1
    widget = Widget.create! name: 'foo', indicator: indicator_2
    assert_cacheable_get :index, params: {sort: 'indicator.agency.name'}
    assert_response :success
    assert_equal widget.id.to_s, json_response['data'].first['id']
  end
end

class IndicatorsControllerTest < ActionController::TestCase
  def teardown
    Widget.delete_all
    Indicator.delete_all
    Agency.delete_all
  end

  def test_fetch_indicators_sort_by_widgets_name
    agency = Agency.create! name: 'test'
    indicator_1 = Indicator.create! import_id: 'bar', name: 'bar', agency: agency
    indicator_2 = Indicator.create! import_id: 'foo', name: 'foo', agency: agency
    Widget.create! name: 'omega', indicator: indicator_1
    Widget.create! name: 'beta', indicator: indicator_1
    Widget.create! name: 'alpha', indicator: indicator_2
    Widget.create! name: 'zeta', indicator: indicator_2
    assert_cacheable_get :index, params: {sort: 'widgets.name'}
    assert_response :success
    assert_equal indicator_2.id.to_s, json_response['data'].first['id']
    assert_equal 2, json_response['data'].size
  end
end
