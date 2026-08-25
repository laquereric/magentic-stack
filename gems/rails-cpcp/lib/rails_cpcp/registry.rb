# frozen_string_literal: true
module RailsCpcp
  # A declared operation projected from a Rails resource.
  Operation = Struct.new(:name, :direction, :params, :result, :handler, :summary, :type_iri, keyword_init: true)

  # A projection of one Rails model/resource into CPCP operations.
  class Projection
    attr_reader :model, :type_iri, :operations

    def initialize(model:, type_iri: nil)
      @model = model.to_s
      @type_iri = type_iri || "#{RailsCpcp.base_iri}/type/#{@model}"
      @operations = {}
    end

    # direction: :pull | :push ; params: required param names ; result: :one | :collection
    def operation(name, direction:, via:, params: [], result: :one, summary: nil)
      dir = direction.to_sym
      raise ArgumentError, "direction must be :pull or :push" unless %i[pull push].include?(dir)
      @operations[name.to_s] = Operation.new(
        name: name.to_s, direction: dir, params: Array(params).map(&:to_s),
        result: result.to_sym, handler: via, summary: summary, type_iri: @type_iri
      )
    end
  end

  # Process-wide registry of declared projections.
  module Registry
    module_function
    def projections; @projections ||= {}; end
    def add(projection); projections[projection.model] = projection; end
    def operations; projections.values.flat_map { |p| p.operations.values }; end
    def find(op_name); operations.find { |o| o.name == op_name.to_s }; end
    def reset!; @projections = {}; end
  end
end
