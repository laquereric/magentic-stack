# frozen_string_literal: true
module RailsThreedotBack
  # Projects the CID-rooted AR model onto the CPCP seam via rails-cpcp. The webview shell
  # reads Context (PULL) and acts (PUSH) through /_cpcp/rpc; the STATIC .threedot/cid.json is
  # only a bootstrap seed for discovery, never a live source. install! from the host app's
  # config/initializers/rails_threedot_back.rb.
  # TODO(build): flesh out via: lambdas -> Cid.as_api etc; PUSH validates + operationId receipt.
  module CpcpProjection
    module_function
    def install!(base_iri: ENV.fetch("THREEDOT_BASE_IRI", "https://threedot.local"))
      return unless defined?(::RailsCpcp)
      RailsCpcp.base_iri = base_iri
      RailsCpcp.project(model: "Cid") do
        operation "threedot.cid",        direction: :pull, params: %w[cid],
          summary: "Fetch a CID (AR root) by iri.",
          via: ->(p, _ctx) { RailsThreedotBack::Cid.find_by(cid_iri: p["cid"])&.as_api || { "error" => "not_found" } }
        operation "threedot.operations", direction: :pull, params: %w[cid],
          summary: "List operations reachable from the CID root.",
          via: ->(p, _ctx) { (RailsThreedotBack::Cid.find_by(cid_iri: p["cid"])&.operations || []).map(&:as_api) }
        operation "threedot.context",    direction: :pull, params: %w[cid],
          summary: "Read grounded Context rooted at the CID.",
          via: ->(p, _ctx) { RailsThreedotBack::Cid.find_by(cid_iri: p["cid"])&.context_api || {} }
        operation "threedot.effect",     direction: :push, params: %w[cid shape],
          summary: "Submit a typed, closed-shape Effect against the CID (idempotent via operationId).",
          via: ->(_p, _ctx) { { "ok" => false, "reason" => "not_implemented", "because" => "threedot.effect - validate closed shape + persist + receipt (see docs/CHARTER.md)" } }
      end
    end
  end
end
