require File.expand_path('../../../test_helper', __FILE__)

class TestOperationsProcessor < JSONAPI::OperationsProcessor
  before_operation :log_before_operation

  after_operation :log_after_operation

  around_operation :log_around_operation

  def log_before_operation
    msg = "Before Operation"
    # puts msg
  end

  def log_around_operation
    msg = "Starting... #{@operation.class.name}"
    # puts msg
    yield
    msg = "... Finishing #{@operation.class.name}"
    # puts msg
  end

  def log_after_operation
    msg = "After Operation"
    # puts msg
  end

  before_operations :log_before_operations

  after_operations :log_after_operations

  around_operations :log_around_operations

  def log_before_operations
    msg = "Before #{@operations.count} Operation(s)"
    # puts msg
  end

  def log_around_operations
    msg = "Starting #{@operations.count} Operation(s)..."
    # puts msg
    yield
    msg = "...Finishing Up Operations"
    # puts msg
  end

  def log_after_operations
    msg =  "After Operations"
    # puts msg
  end
end

class OperationsProcessorTest < Minitest::Test
  def setup
    betax = Planet.find(5)
    betay = Planet.find(6)
    betaz = Planet.find(7)
    unknown = PlanetType.find(5)
  end

  def test_create_single_resource
    op = TestOperationsProcessor.new()

    count = Planet.count

    operations = [
      JSONAPI::CreateResourceOperation.new(PlanetResource, data: {attributes: {'name' => 'earth', 'description' => 'The best planet ever.'}})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(:created, operation_results.results[0].code)
    assert_equal(operation_results.results.size, 1)
    assert_equal(Planet.count, count + 1)
  end

  def test_create_multiple_resources
    op = JSONAPI::OperationsProcessor.new()

    count = Planet.count

    operations = [
      JSONAPI::CreateResourceOperation.new(PlanetResource, data: {attributes: {'name' => 'earth', 'description' => 'The best planet for life.'}}),
      JSONAPI::CreateResourceOperation.new(PlanetResource, data: {attributes: {'name' => 'mars', 'description' => 'The red planet.'}}),
      JSONAPI::CreateResourceOperation.new(PlanetResource, data: {attributes: {'name' => 'venus', 'description' => 'A very hot planet.'}})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 3)
    assert_equal(Planet.count, count + 3)
  end

  def test_replace_has_one_association
    op = JSONAPI::OperationsProcessor.new()

    saturn = Planet.find(1)
    gas_giant = PlanetType.find(1)
    planetoid = PlanetType.find(2)
    assert_equal(saturn.planet_type_id, planetoid.id)

    operations = [
      JSONAPI::ReplaceHasOneAssociationOperation.new(
        PlanetResource,
        {
          resource_id: saturn.id,
          association_type: :planet_type,
          key_value: gas_giant.id
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_kind_of(JSONAPI::OperationResult, operation_results.results[0])
    assert_equal(:no_content, operation_results.results[0].code)

    saturn.reload
    assert_equal(saturn.planet_type_id, gas_giant.id)

    # Remove link
    operations = [
      JSONAPI::ReplaceHasOneAssociationOperation.new(
        PlanetResource,
        {
          resource_id: saturn.id,
          association_type: :planet_type,
          key_value: nil
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    op.process(request)
    saturn.reload
    assert_equal(saturn.planet_type_id, nil)

    # Reset
    operations = [
      JSONAPI::ReplaceHasOneAssociationOperation.new(
        PlanetResource,
        {
          resource_id: saturn.id,
          association_type: :planet_type,
          key_value: 5
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    op.process(request)
    saturn.reload
    assert_equal(saturn.planet_type_id, 5)
  end

  def test_create_has_many_association
    op = JSONAPI::OperationsProcessor.new()

    betax = Planet.find(5)
    betay = Planet.find(6)
    betaz = Planet.find(7)
    gas_giant = PlanetType.find(1)
    unknown = PlanetType.find(5)
    betax.planet_type_id = unknown.id
    betay.planet_type_id = unknown.id
    betaz.planet_type_id = unknown.id
    betax.save!
    betay.save!
    betaz.save!

    operations = [
      JSONAPI::CreateHasManyAssociationOperation.new(
        PlanetTypeResource,
        {
          resource_id: gas_giant.id,
          association_type: :planets,
          data: [betax.id, betay.id, betaz.id]
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    op.process(request)

    betax.reload
    betay.reload
    betaz.reload

    assert_equal(betax.planet_type_id, gas_giant.id)
    assert_equal(betay.planet_type_id, gas_giant.id)
    assert_equal(betaz.planet_type_id, gas_giant.id)

    #   Reset
    betax.planet_type_id = unknown.id
    betay.planet_type_id = unknown.id
    betaz.planet_type_id = unknown.id
    betax.save!
    betay.save!
    betaz.save!
  end

  def test_replace_has_many_association
    op = JSONAPI::OperationsProcessor.new()

    betax = Planet.find(5)
    betay = Planet.find(6)
    betaz = Planet.find(7)
    gas_giant = PlanetType.find(1)
    unknown = PlanetType.find(5)
    betax.planet_type_id = unknown.id
    betay.planet_type_id = unknown.id
    betaz.planet_type_id = unknown.id
    betax.save!
    betay.save!
    betaz.save!

    operations = [
      JSONAPI::ReplaceHasManyAssociationOperation.new(
        PlanetTypeResource,
        {
          resource_id: gas_giant.id,
          association_type: :planets,
          data: [betax.id, betay.id, betaz.id]
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    op.process(request)

    betax.reload
    betay.reload
    betaz.reload

    assert_equal(betax.planet_type_id, gas_giant.id)
    assert_equal(betay.planet_type_id, gas_giant.id)
    assert_equal(betaz.planet_type_id, gas_giant.id)

    #   Reset
    betax.planet_type_id = unknown.id
    betay.planet_type_id = unknown.id
    betaz.planet_type_id = unknown.id
    betax.save!
    betay.save!
    betaz.save!
  end

  def test_replace_attributes
    op = JSONAPI::OperationsProcessor.new()

    count = Planet.count
    saturn = Planet.find(1)
    assert_equal(saturn.name, 'Satern')

    operations = [
      JSONAPI::ReplaceFieldsOperation.new(
        PlanetResource,
        {
          resource_id: 1,
          data: {attributes: {'name' => 'saturn'}}
        }
      )
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)

    assert_kind_of(JSONAPI::ResourceOperationResult, operation_results.results[0])
    assert_equal(:ok, operation_results.results[0].code)

    saturn = Planet.find(1)

    assert_equal(saturn.name, 'saturn')

    assert_equal(Planet.count, count)
  end

  def test_remove_resource
    op = JSONAPI::OperationsProcessor.new

    count = Planet.count
    makemake = Planet.find(2)
    assert_equal(makemake.name, 'Makemake')

    operations = [
      JSONAPI::RemoveResourceOperation.new(PlanetResource, resource_id: 2),
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)

    assert_kind_of(JSONAPI::OperationResult, operation_results.results[0])
    assert_equal(:no_content, operation_results.results[0].code)
    assert_equal(Planet.count, count - 1)
  end

  def test_rollback_from_error
    op = ActiveRecordOperationsProcessor.new

    count = Planet.count

    operations = [
      JSONAPI::RemoveResourceOperation.new(PlanetResource, resource_id: 3),
      JSONAPI::RemoveResourceOperation.new(PlanetResource, resource_id: 4),
      JSONAPI::RemoveResourceOperation.new(PlanetResource, resource_id: 4)
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)

    assert_equal(Planet.count, count)

    assert_equal(operation_results.results.size, 3)

    assert_kind_of(JSONAPI::OperationResult, operation_results.results[0])
    assert_equal(:no_content, operation_results.results[0].code)
    assert_equal(:no_content, operation_results.results[1].code)
    assert_equal(404, operation_results.results[2].code)
  end

  def test_show_operation
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowOperation.new(PlanetResource, {id: '1'})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    refute operation_results.has_errors?
  end

  def test_show_operation_error
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowOperation.new(PlanetResource, {id: '145'})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    assert operation_results.has_errors?
  end

  def test_show_association_operation
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowAssociationOperation.new(PlanetResource, {parent_key: '1', association_type: :planet_type})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    refute operation_results.has_errors?
  end

  def test_show_association_operation_error
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowAssociationOperation.new(PlanetResource, {parent_key: '145', association_type: :planet_type})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    assert operation_results.has_errors?
  end

  def test_show_related_resource_operation
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowRelatedResourceOperation.new(PlanetResource,
                                                {
                                                  source_klass: PlanetResource,
                                                  source_id: '1',
                                                  association_type: :planet_type})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    refute operation_results.has_errors?
  end

  def test_show_related_resource_operation_error
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowRelatedResourceOperation.new(PlanetResource,
                                                {
                                                  source_klass: PlanetResource,
                                                  source_id: '145',
                                                  association_type: :planet_type})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    assert operation_results.has_errors?
  end

  def test_show_related_resources_operation
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowRelatedResourcesOperation.new(PlanetResource,
                                                {
                                                  source_klass: PlanetResource,
                                                  source_id: '1',
                                                  association_type: :moons})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    refute operation_results.has_errors?
  end

  def test_show_related_resources_operation_error
    op = JSONAPI::OperationsProcessor.new

    operations = [
      JSONAPI::ShowRelatedResourcesOperation.new(PlanetResource,
                                                {
                                                  source_klass: PlanetResource,
                                                  source_id: '145',
                                                  association_type: :moons})
    ]

    request = JSONAPI::Request.new
    request.operations = operations

    operation_results = op.process(request)

    assert_kind_of(JSONAPI::OperationResults, operation_results)
    assert_equal(operation_results.results.size, 1)
    assert operation_results.has_errors?
  end
end
