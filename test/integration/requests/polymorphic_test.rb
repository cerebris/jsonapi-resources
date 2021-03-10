require File.expand_path('../../../test_helper', __FILE__)

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
