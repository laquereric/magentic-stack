# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "medallion/version"
require_relative "medallion/layer"
require_relative "medallion/flow"
require_relative "medallion/conformer"
require_relative "medallion/curator"
require_relative "medallion/deprecation"
require_relative "medallion/engine" if defined?(::Rails::Engine)

# Additive mmg_medallion_flow surface (do not clobber layer/flow/curator/conformer)
require_relative "medallion/result"
require_relative "medallion/vocab"
require_relative "medallion/storable_local"
require_relative "medallion/subject_ref"
require_relative "medallion/tier"
require_relative "medallion/seed"
require_relative "medallion/grounding"
require_relative "medallion/promotion"
require_relative "medallion/flow_template"
require_relative "medallion/graph_projection"
require_relative "medallion/medallion_flow"
require_relative "medallion/sal_view"
require_relative "medallion/platform_actions"
require_relative "medallion/purpose"
require_relative "medallion/actionable"
require_relative "medallion/semantic_model"
require_relative "medallion/contract"
require_relative "medallion/provenance"

module Mmg
  # SEMANTIC MEDALLION: Bronze → Silver → Gold projection over RDF named graphs.
  # Migrates + supersedes vv-medallion (Vv::Medallion::Flow / Conformer / Curator).
  # Composes with Mm::GraphMemory retention + Mmg::Curation + SHACL.
  #
  # Additive (mmg_medallion_flow): ONE Tier registry + FlowTemplate DSL +
  # MedallionFlow + grounding/promotion triples + SAL ACIA + MCB.
  module Medallion
    module_function

    def version = VERSION

    def layer(tier) = Layer.contract(tier)
    def retention_hint(tier) = Layer.retention_hint(tier)
    def register_flow(name, **kwargs) = Flow.register(name, **kwargs)

    # Dual surface: legacy Flow registry by name OR new subject-scoped start.
    def flow(name = nil, subject: nil, template: nil, idempotency_key: nil, **kwargs, &block)
      if !subject.nil? || kwargs.key?(:subject) || block || template
        subj = subject || kwargs[:subject]
        return Result.failure(:subject_required, "subject required for medallion flow start") if subj.nil? && name.nil? && block.nil?

        MedallionFlow.start(
          subject: subj || name,
          template: template || kwargs[:template],
          idempotency_key: idempotency_key || kwargs[:idempotency_key],
          &block
        )
      else
        Flow.find(name)
      end
    end

    def deprecation = Deprecation.shim_note
    def deprecate!(legacy) = Deprecation.warn_once!(legacy)

    # M4 probe. True once Conformer requires a provenance stamp on land.
    # EngineBinding asks this rather than parsing method parameters.
    def provenance_required_on_land?
      Conformer.provenance_required_on_land?
    end

    def conform(**kwargs) = Conformer.run(**kwargs)

    # Dual surface: Curator.promote(flow:, silver:) OR MedallionFlow.promote(subject:, to:)
    def promote(**kwargs)
      if kwargs.key?(:subject) || kwargs.key?(:to)
        MedallionFlow.promote(
          subject: kwargs[:subject],
          to: kwargs[:to],
          idempotency_key: kwargs[:idempotency_key],
          stamps: kwargs[:stamps]
        )
      else
        Curator.promote(**kwargs)
      end
    end

    # --- mmg_medallion_flow public API (never-raise) -------------------------

    def seed = Seed.call

    def template(key, &block)
      FlowTemplate.build(key, &block)
    end

    def start_flow(subject:, template: nil, idempotency_key: nil, &block)
      MedallionFlow.start(subject: subject, template: template, idempotency_key: idempotency_key, &block)
    end

    def current(subject:)
      MedallionFlow.current(subject: subject)
    end

    def sal_view(subject:)
      SalView.for(subject: subject)
    end

    def project(event:)
      GraphProjection.new.apply(event)
    end

    def mcb_actions
      PlatformActions.mcb_actions
    end

    def status
      Seed.call if Tier.memory.empty?
      {
        ok: true,
        version: VERSION,
        tiers: Tier.in_rank_order.map(&:to_h),
        actions: mcb_actions.map { |a| a[:name] },
        flow_count: MedallionFlow.store.size
      }
    end

    # Install a thin Vv::Medallion constant shim when the legacy const is absent.
    def install_vv_shim!
      return { ok: true, already: true } if defined?(::Vv::Medallion)

      unless defined?(::Vv)
        Object.const_set(:Vv, Module.new)
      end
      ::Vv.const_set(:Medallion, Module.new) unless ::Vv.const_defined?(:Medallion)
      ::Vv::Medallion.define_singleton_method(:deprecated?) { true }
      ::Vv::Medallion.define_singleton_method(:canonical) { ::Mmg::Medallion }
      ::Vv::Medallion.define_singleton_method(:Flow) do
        ::Mmg::Medallion.deprecate!("Vv::Medallion::Flow")
        ::Mmg::Medallion::Flow
      end
      ::Vv::Medallion.define_singleton_method(:Conformer) do
        ::Mmg::Medallion.deprecate!("Vv::Medallion::Conformer")
        ::Mmg::Medallion::Conformer
      end
      ::Vv::Medallion.define_singleton_method(:Curator) do
        ::Mmg::Medallion.deprecate!("Vv::Medallion::Curator")
        ::Mmg::Medallion::Curator
      end
      Deprecation.warn_once!("vv-medallion")
      { ok: true, shim: "Vv::Medallion → Mmg::Medallion" }
    rescue ::StandardError => e
      { ok: false, reason: :shim_failed, because: "#{e.class}: #{e.message}" }
    end

    def load_models!
      return false unless defined?(::ActiveRecord::Base)

      path = File.expand_path("../../app/models/mmg/medallion/tier_record.rb", __dir__)
      require path if File.file?(path)
      true
    rescue ::LoadError, ::StandardError
      false
    end
  end
end

Mmg::Medallion.load_models! if defined?(::ActiveRecord::Base)
