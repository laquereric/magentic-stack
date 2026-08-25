# frozen_string_literal: true
# rails-cpcp: project selected Rails resources as CID-grounded JSON-RPC-LD operations.
RailsCpcp.base_iri = ENV.fetch("CPCP_BASE_IRI", "https://cpcp.local")

# Example projection (edit for your models). operationId is implicit for PUSH.
# RailsCpcp.project(model: "Build") do
#   operation "build.list",   direction: :pull, result: :collection,
#     summary: "List builds",   via: ->(p, ctx) { Build.recent.limit(50).map(&:as_api) }
#   operation "build.get",    direction: :pull, params: %w[id],
#     summary: "Get one build", via: ->(p, ctx) { Build.find(p["id"]).as_api }
#   operation "build.create", direction: :push, params: %w[kind spec],
#     summary: "Create a build", via: ->(p, ctx) {
#       Build.create!(kind: p["kind"], spec: p["spec"], status: "queued", user: ctx.try(:current_user)).as_api
#     }
# end
