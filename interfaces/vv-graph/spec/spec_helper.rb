# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "vv-graph"
require_relative "support/extension_environment"
require_relative "support/engine_gap_quarantine"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  # S2 harness: per-example isolation for shared Oxigraph + ProjectionJob
  # outbox. Without this, publisher/storable/s2 files pass alone but fail
  # together (applied_generation coalesce bleed, graph query bleed).
  config.before(:each) do
    Vv::Graph.reset_publisher! if defined?(Vv::Graph)

    if defined?(Vv::Graph::ProjectionJob) &&
       Vv::Graph::ProjectionJob.respond_to?(:available?) &&
       Vv::Graph::ProjectionJob.available?
      Vv::Graph::ProjectionJob.delete_all
    end
  end

  # Live graph specs (Oxigraph). Skip when sidecar unavailable.
  config.before(:each, :requires_extension) do
    unless Vv::Graph::SpecSupport::ExtensionEnvironment.available?
      skip Vv::Graph::SpecSupport::ExtensionEnvironment.skip_reason
    end
    Vv::Graph::SpecSupport::ExtensionEnvironment.reset_store!
    if defined?(Vv::Graph::ProjectionJob) && Vv::Graph::ProjectionJob.available?
      Vv::Graph::ProjectionJob.delete_all
    end
    Vv::Graph.reset_publisher!
  end
end
