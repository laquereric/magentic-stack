# frozen_string_literal: true
module RailsCpcp
  module_function

  # Base IRI used to mint @id / type / operation IRIs. Configure in an initializer.
  def base_iri; @base_iri ||= "https://cpcp.local"; end
  def base_iri=(value); @base_iri = value.to_s.sub(%r{/\z}, ""); end

  # The CPCP / JSON-RPC-LD-PS1 term vocabulary (the ontology this projects into).
  def standard_iri; "https://w3id.org/laquereric/cpcp/ns#"; end

  # Declare a projection of a Rails resource into CPCP operations.
  #
  #   RailsCpcp.project(model: "Build") do
  #     operation "build.list",  direction: :pull, result: :collection, via: ->(p, ctx) { Build.recent.map(&:as_api) }
  #     operation "build.get",   direction: :pull, params: %w[id],       via: ->(p, ctx) { Build.find(p["id"]).as_api }
  #     operation "build.create",direction: :push, params: %w[operationId kind spec], via: ->(p, ctx) { ... }
  #   end
  def project(model:, type_iri: nil, &blk)
    proj = Projection.new(model: model, type_iri: type_iri)
    proj.instance_eval(&blk) if blk
    Registry.add(proj)
    proj
  end
end
