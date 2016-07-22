require File.expand_path('../../../test_helper', __FILE__)

class ValidatedRequestTest < ActionDispatch::IntegrationTest
  def subject_resource
    Api::V3::BookResource
  end

  def subject_processor
    Api::V3::BookProcessor
  end

  def include_klass(klass, &block)
    klass.include(Module.new(&block))
  end

  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
    JSONAPI.configuration.route_format    = :underscored_route
    $test_user = Person.find(2)

    include_klass subject_processor do
      def validate
        if context[:current_user].id != 1
          errors.add(:current_user, "Needs to be of ID 1 Only! 🦄")
        end
      end
    end
  end

  def after_teardown
    Api::V3::BookResource.paginator(:offset)
    JSONAPI.configuration.route_format = :underscored_route
    $test_user = nil

    include_klass subject_processor do
      def validate
      end
    end
  end

  def test_read_access_with_validation
    get "/api/v3/books", headers: { "Accept" => JSONAPI::MEDIA_TYPE }
    assert_equal(true, false, "TODO IMPLEMENT")
  end
end
