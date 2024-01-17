require File.expand_path('../../../test_helper', __FILE__)

# copied from https://github.com/cerebris/jsonapi-resources/blob/e60dc7dd2c7fdc85834163a7e706a10a8940a62b/test/integration/requests/polymorphic_test.rb
# https://github.com/cerebris/jsonapi-resources/compare/bf4_fix_polymorphic_relations_lookup?expand=1
class PolymorphicTest < ActionDispatch::IntegrationTest

  def json_api_headers
    {'Accept' => JSONAPI::MEDIA_TYPE, 'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE}
  end

  def test_find_party_via_contact_medium
    individual = Individual.create(name: 'test')
    contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
    fetched_party = contact_medium.party
    assert_same individual, fetched_party, "Expect an individual to have been found via contact medium model's relationship 'party'"
  end

  def test_get_individual
    individual = Individual.create(name: 'test')
    ContactMedium.create(party: individual, name: 'test contact medium')
    get "/individuals/#{individual.id}"
    assert_jsonapi_response 200
  end

  def test_get_party_via_contact_medium
    individual = Individual.create(name: 'test')
    contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
    get "/contact_media/#{contact_medium.id}/party"
    assert_jsonapi_response 200, "Expect an individual to have been found via contact medium resource's relationship 'party'"
  end
end

# copied from https://github.com/cerebris/jsonapi-resources/pull/1349/files
# require File.expand_path('../test_helper', __FILE__)
#
# Replace this with the code necessary to make your test fail.
# class BugTest < Minitest::Test
#   include Rack::Test::Methods
#
#   def json_api_headers
#     {'Accept' => JSONAPI::MEDIA_TYPE, 'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE}
#   end
#
#   def teardown
#     Individual.delete_all
#     ContactMedium.delete_all
#   end
#
#   def test_find_party_via_contact_medium
#     individual = Individual.create(name: 'test')
#     contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
#     fetched_party = contact_medium.party
#     assert_same individual, fetched_party, "Expect an individual to have been found via contact medium model's relationship 'party'"
#   end
#
#   def test_get_individual
#     individual = Individual.create(name: 'test')
#     ContactMedium.create(party: individual, name: 'test contact medium')
#     get "/individuals/#{individual.id}"
#     assert_last_response_status 200
#   end
#
#   def test_get_party_via_contact_medium
#     individual = Individual.create(name: 'test')
#     contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
#     get "/contact_media/#{contact_medium.id}/party"
#     assert_last_response_status 200, "Expect an individual to have been found via contact medium resource's relationship 'party'"
#   end
#
#   private
#
#   def assert_last_response_status(status, failure_reason=nil)
#     if last_response.status != status
#       json_response = JSON.parse(last_response.body) rescue last_response.body
#       pp json_response
#     end
#     assert_equal status, last_response.status, failure_reason
#   end
#
#   def app
#     Rails.application
#   end
# end
