require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

require 'json/api/operation'
require 'json/api/operation_result'
require 'json/api/operations_processor'

class OperationsProcessorTest < MiniTest::Unit::TestCase
  def setup
  end

  def test_create_single_resource
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count

    operations = [
      JSON::API::AddResourceOperation.new(PlanetResource, {'name' => 'earth', 'description' => 'The best planet ever.'})
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_kind_of(JSON::API::OperationResult, results[0])
    assert_equal(:created, results[0].code)
    assert_equal(results.size, 1)
    assert_equal(Planet.count, count + 1)
  end

  def test_create_multiple_resources
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count

    operations = [
        JSON::API::AddResourceOperation.new(PlanetResource, {'name' => 'earth', 'description' => 'The best planet for life.'}),
        JSON::API::AddResourceOperation.new(PlanetResource, {'name' => 'mars', 'description' => 'The red planet.'}),
        JSON::API::AddResourceOperation.new(PlanetResource, {'name' => 'venus', 'description' => 'A very hot planet.'})
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_equal(results.size, 3)
    assert_equal(Planet.count, count + 3)
  end

  def test_add_has_one_association
    op = JSON::API::OperationsProcessor.new()

    saturn = Planet.find(1)
    gas_giant = PlanetType.find(1)
    planetoid = PlanetType.find(2)
    assert_equal(saturn.planet_type_id, planetoid.id)


    operations = [
      JSON::API::AddHasOneAssociationOperation.new(PlanetResource, saturn.id, :planet_type, :planet_type_id, gas_giant.id)
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_kind_of(JSON::API::OperationResult, results[0])
    assert_equal(:created, results[0].code)
    assert_equal(results[0].resource.object.attributes['planet_type_id'], gas_giant.id)
  end

  def test_add_has_many_association
    op = JSON::API::OperationsProcessor.new()

    betax = Planet.find(5)
    betay = Planet.find(6)
    betaz = Planet.find(7)
    gas_giant = PlanetType.find(1)
    unknown = PlanetType.find(5)
    assert_equal(betax.planet_type_id, unknown.id)
    assert_equal(betay.planet_type_id, unknown.id)
    assert_equal(betaz.planet_type_id, unknown.id)

    operations = [
        JSON::API::AddHasManyAssociationOperation.new(PlanetTypeResource, gas_giant.id, :planets, :planet_type_ids, [betax.id, betay.id, betaz.id])
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    betax.reload
    betay.reload
    betaz.reload

    assert_equal(betax.planet_type_id, gas_giant.id)
    assert_equal(betay.planet_type_id, gas_giant.id)
    assert_equal(betaz.planet_type_id, gas_giant.id)
  end

  def test_replace_attributes
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count
    saturn = Planet.find(1)
    assert_equal(saturn.name, 'Satern')

    operations = [
        JSON::API::ReplaceAttributesOperation.new(PlanetResource, 1, {'name' => 'saturn'}),
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_equal(results.size, 1)

    assert_kind_of(JSON::API::OperationResult, results[0])
    assert_equal(:ok, results[0].code)

    saturn = Planet.find(1)

    assert_equal(saturn.name, 'saturn')

    assert_equal(Planet.count, count)
  end

  def test_remove_resource
    op = JSON::API::OperationsProcessor.new

    count = Planet.count
    pluto = Planet.find(2)
    assert_equal(pluto.name, 'Pluto')

    operations = [
        JSON::API::RemoveResourceOperation.new(PlanetResource, 2),
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_equal(results.size, 1)

    assert_kind_of(JSON::API::OperationResult, results[0])
    assert_equal(:no_content, results[0].code)
    assert_equal(Planet.count, count - 1)
  end

  def test_rollback_from_error
    op = JSON::API::ActiveRecordOperationsProcessor.new

    count = Planet.count

    operations = [
        JSON::API::RemoveResourceOperation.new(PlanetResource, 3),
        JSON::API::RemoveResourceOperation.new(PlanetResource, 4),
        JSON::API::RemoveResourceOperation.new(PlanetResource, 4)
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_equal(Planet.count, count)

    assert_kind_of(Array, results)
    assert_equal(results.size, 3)

    assert_kind_of(JSON::API::OperationResult, results[0])
    assert_equal(:no_content, results[0].code)
    assert_equal(:no_content, results[1].code)
    assert_equal(404, results[2].code)
  end

end
