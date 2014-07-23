require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

require 'json/api/operation'
require 'json/api/operation_result'
require 'json/api/operations_processor'

class OperationsProcessorTest < MiniTest::Unit::TestCase
  def setup
  end

  def test_create_single
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count

    operations = [
      JSON::API::Operation.new(PlanetResource, :add, nil, '/-', {'name' => 'earth', 'description' => 'The best planet ever.'})
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

  def test_create_multiple
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count

    operations = [
        JSON::API::Operation.new(PlanetResource, :add, nil, '/-', {'name' => 'earth', 'description' => 'The best planet for life.'}),
        JSON::API::Operation.new(PlanetResource, :add, nil, '/-', {'name' => 'mars', 'description' => 'The red planet.'}),
        JSON::API::Operation.new(PlanetResource, :add, nil, '/-', {'name' => 'venus', 'description' => 'A very hot planet.'})
    ]

    request = JSON::API::Request.new
    request.operations = operations

    results = op.process(request)

    assert_kind_of(Array, results)
    assert_equal(results.size, 3)
    assert_equal(Planet.count, count + 3)
  end

  def test_replace
    op = JSON::API::OperationsProcessor.new()

    count = Planet.count
    saturn = Planet.find(1)
    assert_equal(saturn.name, 'Satern')

    operations = [
        JSON::API::Operation.new(PlanetResource, :replace, 1, '/-', {'name' => 'saturn'}),
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

  def test_remove
    op = JSON::API::OperationsProcessor.new

    count = Planet.count
    pluto = Planet.find(2)
    assert_equal(pluto.name, 'Pluto')

    operations = [
        JSON::API::Operation.new(PlanetResource, :remove, 2, '/-'),
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

  def test_rollback
    op = JSON::API::ActiveRecordOperationsProcessor.new

    count = Planet.count

    operations = [
        JSON::API::Operation.new(PlanetResource, :remove, 3, '/-'),
        JSON::API::Operation.new(PlanetResource, :remove, 4, '/-'),
        JSON::API::Operation.new(PlanetResource, :remove, 4, '/-'),
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
