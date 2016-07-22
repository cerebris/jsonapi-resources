require File.expand_path('../../../test_helper', __FILE__)

class ProcessorTest < Minitest::Test
  def build_request
    ActionDispatch::TestRequest.new({}).tap do |req|
      req.host = "foobar-host.com"
    end
  end

  def subject_record_id
    1
  end

  def default_processor_options
    {
      context: {
        request: build_request
      },
      id: subject_record_id
    }
  end

  def build_processor(params = default_processor_options)
    JSONAPI::Processor.new(PlanetResource, :show, params)
  end

  def extend_processor_instance(instance, &block)
    instance.extend(Module.new(&block))
  end

  def test_process_without_validation
    processor = build_processor
    subject   = processor.process
    record    = subject.resource.instance_variable_get("@model")

    assert_equal(subject.code, :ok, "Returns the expected operation result")
    assert_equal(record.id, subject_record_id, "Returns the expected record")
    assert_equal(processor.errors.empty?, true, "without a validation executed, does not find errors")
  end

  def test_process_with_validation
    processor = build_processor

    extend_processor_instance processor do
      def validate
        errors.add(:request, "Invalid request host") if context[:request].host.match(/foo/)
      end
    end

    subject = processor.process
    assert_equal(subject.code, :unprocessable_entity, "Returns the expected operation result")
    assert_equal(subject.errors.empty?, false, "Populates errors correctly")
    assert_equal(subject.errors[:request], ["Invalid request host"], "shows the right error messages")
  end
end
