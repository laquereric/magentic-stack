# mmg-medallion Design Specification (Ruby gem additive design)

Status: Additive Ruby 3.4 / Rails 8 design for the MagenticMarket substrate. The gem provides a canonical, single ActiveRecord-backed Medallion registry and a full semantic-flow stack that grounds RDF subjects through Bronze → Silver → Gold progressions. All transitions are durable, replayable, and exposed via a never-raise API surface. A reusable FlowTemplate/Builder DSL enables constructing standardized flows; and a single ACIA subtree is rendered to all surfaces via mmg-sal/mmg-render.

Executive invariants
- There is ONE ActiveRecord table: medallions. It stores exactly three canonical tiers (Bronze, Silver, Gold) with immutable naming/description semantics. All per-subject state and transitions are represented via RDF grounding and RES events, not additional AR state.
- A subject can progress Bronze -> Silver -> Gold only; reverse or non-adjacent promotions are rejected with a never-raise result here, and suitable error details are returned to the caller.
- Grounding triples and promotion history are produced as durable RDF events and projections; views consume a single ACIA subtree under mmg-sal/mmg-render.

1) ActiveRecord schema: Medallions (canonical registry)
- Migration (single table, canonical constraints)

```ruby
# db/migrate/20260922000000_create_medallions.rb
# frozen_string_literal: true

class CreateMedallions < ActiveRecord::Migration[8.0]
  def change
    create_table :medallions do |t|
      t.string  :name,        null: false
      t.integer :rank,        null: false
      t.string  :slug,        null: false
      t.text    :description, null: false
    end

    add_index :medallions, :slug, unique: true, name: "index_medallions_on_slug_unique"
    add_index :medallions, :rank, unique: true, name: "index_medallions_on_rank_unique"
    add_index :medallions, :name, unique: true, name: "index_medallions_on_name_unique"

    add_check_constraint :medallions, "rank IN (1, 2, 3)", name: "medallions_rank_is_canonical"

    # The canonical set is enforced by a multi-column constraint that prohibits
    # any non-canonical tuple. The idempotent seed guarantees Bronze/Silver/Gold exist.
    add_check_constraint :medallions, <<~SQL.squish, name: "medallions_are_canonical_tiers"
      (
        slug = 'bronze' AND name = 'Bronze' AND rank = 1 AND
        description = 'Raw / ingested data.'
      ) OR (
        slug = 'silver' AND name = 'Silver' AND rank = 2 AND
        description = 'Cleaned / conformed data.'
      ) OR (
        slug = 'gold' AND name = 'Gold' AND rank = 3 AND
        description = 'Curated / business-ready data.'
      )
    SQL
  end
end
```

- Model (namespaced) with grounding and seed

```ruby
# app/models/mmg/medallion.rb
# frozen_string_literal: true

module Mmg
  class Medallion < ::ApplicationRecord
    include Vv::Graph::Storable

    self.table_name = "medallions"

    CANONICAL_ROWS = [
      { name: "Bronze", rank: 1, slug: "bronze", description: "Raw / ingested data." }.freeze,
      { name: "Silver", rank: 2, slug: "silver", description: "Cleaned / conformed data." }.freeze,
      { name: "Gold", rank: 3, slug: "gold", description: "Curated / business-ready data." }.freeze
    ].freeze

    CANONICAL_BY_SLUG = CANONICAL_ROWS.index_by { |r| r[:slug] }.freeze

    validates :slug, inclusion: { in: CANONICAL_BY_SLUG.keys }
    validates :slug, :rank, :name, uniqueness: true
    validate :canonical_tuple

    scope :in_rank_order, -> { order(:rank) }

    def self.for(slug); find_by(slug: slug.to_s); end
    def self.canonical?(slug); CANONICAL_BY_SLUG.key?(slug.to_s); end

    def iri
      Vocab.tier(slug)
    end
    def successor_iri
      Vocab.tier_for_rank(rank + 1)
    end

    triples do
      triple iri, Vocab::RDF_TYPE, Vocab::MEDALLION_TIER
      triple iri, Vocab::RDFS_LABEL, name
      triple iri, Vocab::SLUG, slug
      triple iri, Vocab::RANK, rank
      triple iri, Vocab::DESCRIPTION, description
      triple iri, Vocab::PROMOTES_TO_TIER, successor_iri if successor_iri
    end

    private

    def canonical_tuple
      expected = CANONICAL_BY_SLUG[slug]
      return errors.add(:slug, "is not a canonical medallion tier") unless expected
      expected.each do |attribute, expected_value|
        actual_value = public_send(attribute)
        next if actual_value == expected_value
        errors.add(attribute, "must be #{expected_value.inspect} for #{slug}")
      end
    end
  end
end
```

- Seed (idempotent canonical seed)

```ruby
# db/seeds/mmg_medallion.rb
# frozen_string_literal: true

result = Mmg::Medallion::Seed.call
Rails.logger.error("mmg-medallion seed failed: #{result[:because]}") unless result[:ok]

# lib/mmg/medallion/seed.rb
module Mmg
  class Medallion
    class Seed
      def self.call
        Result.capture(reason: :medallion_seed_failed) do
          Mmg::Medallion.transaction do
            Mmg::Medallion.upsert_all(
              Mmg::Medallion::CANONICAL_ROWS,
              unique_by: :index_medallions_on_slug_unique,
              update_only: %i[name rank description]
            )
          end

          rows = Mmg::Medallion.in_rank_order.to_a
          { seeded: rows.map(&:slug), count: rows.length, medallions: rows }
        end
      end
    end
  end
end
```

2) RDF grounding vocabulary and grounding semantics
- Canonical vocabulary (Vocab module) defines stable IRIs and predicates used across all subjects. Grounding is expressed as a single current mm:medallionTier triple per subject, while transitions produce an immutable mm:Promotion resource and associated provenance stamps.

```ruby
# lib/mmg/medallion/vocab.rb
# frozen_string_literal: true

require "digest"

module Mmg
  class Medallion
    module Vocab
      BASE          = "https://magentic.market".freeze
      MM            = "#{BASE}/ns/mm#".freeze
      MEDALLION_ROOT = "#{BASE}/id/medallion".freeze
      TIER_GRAPH    = "#{BASE}/graph/mmg-medallion/tiers".freeze

      RDF_TYPE      = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type".freeze
      RDFS_LABEL    = "http://www.w3.org/2000/01/rdf-schema#label".freeze
      SLUG          = "#{MM}slug".freeze
      RANK          = "#{MM}rank".freeze
      DESCRIPTION   = "#{MM}description".freeze

      MEDALLION_TIER    = "#{MM}MedallionTier".freeze
      MEDALLION_FLOW    = "#{MM}MedallionFlow".freeze
      PROMOTION         = "#{MM}Promotion".freeze
      PROMOTED_FROM     = "#{MM}promotedFrom".freeze
      PROMOTED_TO       = "#{MM}promotedTo".freeze
      PROMOTES_TO_TIER  = "#{MM}promotesToTier".freeze
      SUBJECT           = "#{MM}subject".freeze
      FLOW              = "#{MM}flow".freeze
      FLOW_TEMPLATE     = "#{MM}flowTemplate".freeze

      MEDALLION_TIER_P  = "#{MM}medallionTier".freeze

      module_function
      def tier(slug); "#{MEDALLION_ROOT}/#{slug}"; end
      def tier_for_rank(rank); { 1 => tier("bronze"), 2 => tier("silver"), 3 => tier("gold") }[rank]; end
      def flow(subject_iri); "#{BASE}/id/medallion-flow/#{Digest::SHA256.hexdigest(subject_iri)}"; end
      def promotion(event_id); "#{BASE}/id/medallion-promotion/#{event_id}"; end
      def stamp(event_id, ordinal); "#{BASE}/id/medallion-stamp/#{event_id}/#{ordinal}"; end
    end
  end
end
```

- Grounding triples are produced by MedallionGrounding (subject -> mm:medallionTier → canonical tier IRIs) and by MedallionFlow grounding to the active tier.

```ruby
# lib/mmg/medallion/grounding.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    class Grounding
      include Vv::Graph::Storable

      attr_reader :subject_ref, :tier

      def initialize(subject_ref:, tier:)
        @subject_ref = subject_ref
        @tier = tier
      end

      triples do
        triple subject_ref.iri, Vocab::MEDALLION_TIER_P, tier.iri
      end
    end
  end
end
```

- Promotion events link the old and new tier and carry provenance.

```ruby
# lib/mmg/medallion/promotion.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    class Promotion
      include Vv::Graph::Storable

      attr_reader :event_id, :flow_iri, :subject_ref, :from_tier, :to_tier,
                  :occurred_at, :stamps

      def initialize(event_id:, flow_iri:, subject_ref:, from_tier:, to_tier:, occurred_at:, stamps: [])
        @event_id = event_id
        @flow_iri = flow_iri
        @subject_ref = subject_ref
        @from_tier = from_tier
        @to_tier = to_tier
        @occurred_at = occurred_at
        @stamps = stamps.freeze
      end

      def iri
        Vocab.promotion(event_id)
      end

      triples do
        triple iri, Vocab::RDF_TYPE, Vocab::PROMOTION
        triple iri, Vocab::FLOW, flow_iri
        triple iri, Vocab::SUBJECT, subject_ref.iri
        triple iri, Vocab::PROMOTED_FROM, from_tier.iri
        triple iri, Vocab::PROMOTED_TO, to_tier.iri
        triple iri, Vocab::OCCURRED_AT, occurred_at.iso8601
      end
    end
  end
end
```

3) FlowTemplate/Builder DSL for reusable medallion semantic flows
- FlowTemplate is a pure Ruby declarative container with a fixed Bronze → Silver → Gold lifecycle. It supports stage-scoped stamps and guards against missing or duplicate stages. A FlowTemplate can be materialized into a MedallionFlow for a subject.

```ruby
# lib/mmg/medallion/flow_template.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    class FlowTemplate
      STAGES = %w[bronze silver gold].freeze

      attr_reader :key, :stamps_by_stage

      def initialize(key:, stamps_by_stage:)
        @key = key.to_s.freeze
        @stamps_by_stage = stamps_by_stage.transform_values(&:freeze).freeze
      end

      def iri
        "#{Vocab::BASE}/id/medallion-template/#{key}"
      end

      def stamps_for(stage)
        stamps_by_stage.fetch(stage.to_s, [])
      end

      class Builder
        def initialize(key:)
          @key = key
          @stamps_by_stage = {}
        end

        def bronze(&block) = stage("bronze", &block)
        def silver(&block) = stage("silver", &block)
        def gold(&block)   = stage("gold", &block)

        def build
          missing = STAGES - @stamps_by_stage.keys
          return Result.failure(:invalid_flow_template, "missing stages: #{missing.join(', ')}") if missing.any?

          FlowTemplate.new(key: @key, stamps_by_stage: @stamps_by_stage)
        end

        private

        def stage(name)
          return Result.failure(:duplicate_stage, "#{name} may be declared once") if @stamps_by_stage.key?(name)

          collector = StampCollector.new
          collector.instance_eval(&Proc.new) if block_given?
          @stamps_by_stage[name] = collector.stamps
          Result.success(stage: name)
        end
      end

      class StampCollector
        attr_reader :stamps

        def initialize
          @stamps = []
        end

        def stamp(**pairs)
          pairs.each { |key, value| @stamps << { key: key.to_s, value: value.to_s }.freeze }
          Result.success(stamps: @stamps)
        end
      end
    end
  end
end
```

- Flow invocation: create a subject-scoped flow with Bronze → Silver → Gold, then start the flow and emit a durable flow_started event. Promotions are modeled as separate commands that emit medallion.promoted.v1 events.

```ruby
# Mmg::Medallion.template(...) returns a FlowTemplate, or a Flow object via FlowTemplate.Builder
# Mmg::Medallion.flow(subject:, template:, idempotency_key:, &block) -> creates a MedallionFlow and starts Bronze
# Mmg::Medallion.promote(subject:, to:, idempotency_key:, &block) -> performs adjacent promotion
```

4) Never-raise public API surface
- All public API calls return a uniform Result-like envelope: { ok: true, ... } or { ok: false, reason:, because: ... }. The Result helper normalizes errors (validation, conflicts, invalid subjects, invalid templates, illegal transitions) and never raises outward.

```ruby
# lib/mmg/medallion/result.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    module Result
      module_function

      def success(**payload); { ok: true, **payload }; end
      def failure(reason, because); { ok: false, reason: reason.to_sym, because: because.to_s }; end
      def capture(reason:); payload = yield; return payload if payload.is_a?(Hash) && payload.key?(:ok); success(**payload); rescue ActiveRecord::RecordInvalid => error; failure(:validation_failed, error.record.errors.full_messages.join(", ")); rescue ActiveRecord::RecordNotUnique; failure(:conflict, "a canonical or idempotency uniqueness constraint was violated"); rescue StandardError => error; failure(reason, error.message); end
    end
  end
end
```

- Public entry points on Mmg::Medallion maintain the never-raise contract:
  - Mmg::Medallion.seed (idempotent)
  - Mmg::Medallion.template(key, &block)
  - Mmg::Medallion.flow(subject:, template:, idempotency_key:, &block)
  - Mmg::Medallion.promote(subject:, to:, idempotency_key:, &block)
  - Mmg::Medallion.current(subject:)
  - Mmg::Medallion.project(event:)
  - Mmg::Medallion.sal_view(subject:)

5) Graph projection (RES → RDF) and SAL rendering
- The RES event log is the single source of truth for domain state changes. A GraphProjection consumes MEDALLION events and upserts RDF triples into a canonical named graph, then exposes an ACIA subtree to SAL renderers. The projection is idempotent and deterministic, driven by event_id.

```ruby
# lib/mmg/medallion/graph_projection.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    class GraphProjection
      def initialize(graph_sink: Mmg::GraphSink.default)
        @graph_sink = graph_sink
      end

      def apply(event)
        Result.capture(reason: :graph_projection_failed) do
          case event.type
          when "medallion.flow_started.v1"
            apply_current_grounding(event, tier_slug: "bronze")
            apply_flow_resource(event)
          when "medallion.promoted.v1"
            apply_current_grounding(event, tier_slug: event.data.fetch(:to_tier_slug))
            apply_promotion_resource(event)
          else
            return Result.failure(:unsupported_event, "#{event.type} is not a medallion event")
          end

          { event_id: event.id, projected: true }
        end
      end

      private

      def apply_current_grounding(event, tier_slug:)
        subject_ref = SubjectRef.new(
          iri: event.data.fetch(:subject_iri),
          graph_iri: event.data.fetch(:graph_iri)
        )
        tier = Mmg::Medallion.for(tier_slug)
        return Result.failure(:tier_registry_incomplete, "#{tier_slug} is absent") unless tier

        grounding = Grounding.new(subject_ref: subject_ref, tier: tier)

        @graph_sink.replace_subject_predicate(
          graph_iri: subject_ref.graph_iri,
          subject_iri: subject_ref.iri,
          predicate_iri: Vocab::MEDALLION_TIER_P,
          storable: grounding,
          idempotency_key: event.id
        )
      end

      def apply_flow_resource(event)
        @graph_sink.upsert_storable(
          graph_iri: event.data.fetch(:graph_iri),
          storable: FlowResource.from_event(event),
          idempotency_key: event.id
        )
      end

      def apply_promotion_resource(event)
        @graph_sink.upsert_storable(
          graph_iri: event.data.fetch(:graph_iri),
          storable: Promotion.from_event(event),
          idempotency_key: event.id
        )
      end
    end
  end
end
```

- SAL view: a single ACIA subtree that represents the MedallionFlow, consumed by mmg-sal/mmg-render.

```ruby
# lib/mmg/medallion/sal_view.rb
# frozen_string_literal: true

module Mmg
  class Medallion
    class SalView
      def self.for(subject:)
        Result.capture(reason: :sal_view_failed) do
          current = Mmg::Medallion.current(subject: subject)
          return current unless current[:ok]

          flow = current.fetch(:flow)
          tier = current.fetch(:tier)
          { node: new(flow: flow, current_tier: tier).acia_node }
        end
      end

      def initialize(flow:, current_tier:)
        @flow = flow
        @current_tier = current_tier
      end

      def acia_node
        AcIa::Node.build(
          id: "medallion-flow:#{@flow.iri}",
          kind: :group,
          semantic_role: :medallion_flow,
          label: "Medallion refinement flow",
          properties: {
            subject_iri: @flow.subject_ref.iri,
            current_tier: @current_tier.slug,
            flow_iri: @flow.iri
          },
          children: Mmg::Medallion::FlowTemplate::STAGES.map { |slug| tier_node(slug) }
        )
      end

      private

      def tier_node(slug)
        tier = Mmg::Medallion.for(slug)
        state = if tier.rank < @current_tier.rank
                  :complete
                elsif tier.rank == @current_tier.rank
                  :current
                else
                  :pending
                end

        AcIa::Node.build(
          id: "medallion-flow:#{@flow.iri}:tier:#{slug}",
          kind: :step,
          semantic_role: :medallion_tier,
          label: tier.name,
          description: tier.description,
          state: state,
          properties: {
            tier_iri: tier.iri,
            rank: tier.rank,
            current: state == :current
          }
        )
      end
    end
  end
end
```

6) Flow lifecycle, events, and surface rendering
- Flow starts Bronze (flow_started.v1) with Bronze stamps; each adjacent promotion emits a medallion.promoted.v1 event and a Promotion resource. The current tier triple is replaced via GraphProjection, but the Promotion resource persists for audit/history.

```mermaid
sequenceDiagram
  participant C as Caller
  participant D as FlowTemplate Builder
  participant R as Medallion AR Registry
  participant E as RES Event Log
  participant P as GraphProjection
  participant G as Named RDF Graph
  participant S as SalView / ACIA

  C->>D: Mmg::Medallion.flow(subject:) { bronze; silver; gold }
  D->>R: resolve Bronze/Silver/Gold canonical rows
  D->>E: append medallion.flow_started.v1 (Bronze stamps)
  E->>P: durable event / replay dispatch
  P->>G: write Bronze grounding triples
  P->>S: build single ACIA subtree

  C->>E: Mmg::Medallion.promote(subject:, to: :silver)
  E->>P: append medallion.promoted.v1
  P->>G: replace current tier to Silver; upsert Promotion
  P->>S: update ACIA subtree with Silver current
```

7) SAL/ACIA rendering surfaces
- There is one ACIA subtree per flow; mmg-sal/mmg-render consume that subtree without forking. The SalView exposes a stable ACIA representation consisting of a root medallion-flow node and three tier-nodes (Bronze, Silver, Gold) with current/complete/pending states.

8) Acceptance criteria and boundaries
- The registry contains exactly three canonical rows: Bronze, Silver, Gold; no other AR rows are permitted. The idempotent seed guarantees the canonical rows exist and remain stable. Grounding and promotion are grounded in canonical tier IRIs. The RES event log drives the projection; the projection writes to a named graph; a single ACIA subtree is used for all surfaces.

9) Graph map and surfaces (MMG graph map)
- The graph map is committed in the public repository as an additive, machine-editable Mermaid source mmg-medallion-graph.mmd and its rendered PNG mmg-medallion-graph.png. The diagram shows the canonical registry, the flow, the grounding, the promotion, and the projection surfaces, plus the ACIA subtree and the SalView rendering route.

10) Public API surface overview
- The gem exposes a never-raise surface for: Seed, Flow template creation, Flow start, Promotion, Current view, and SAL view projection. All operations produce a uniform payload with ok: true/false and informative details on success or failure.

References
- Rails Active Record Migrations (standard migration DSL, unique indexes, and constraints) [1]
- RDF 1.1 Concepts (triples, graphs, named graphs) [2]

Notes
- The repository contains the additive files mmg-medallion.rb and subcomponents under lib/mmg/medallion, the AR model, the vocabulary, the grounding/promotion code, the FlowTemplate/Flow DSL, GraphProjection, and SAL-related views. It also includes the single seed and the migration required to instantiate Bronze/Silver/Gold.

Graph and artifact files included in the final handoff package
- Graph: mmg-medallion-graph.mmd (Mermaid source)
- Rendered graph: mmg-medallion-graph.png
- Design Markdown: MMG_MEDALLION_DESIGN.md

Appendix: Grounding and vocabulary notes
- Grounding predicate mm:medallionTier identifies the subject's current canonical tier. Each promotion uses mm:promotedFrom and mm:promotedTo to preserve promotion provenance. The flow is anchored to a Flow IRI; subject IRI and graph IRI are carried on the Flow and Promotion events. The GraphProjection uses Vv::Graph::Storable to emit triples to the named graph mmg-medallion/tiers, and ACIA renders as a single subtree consumed by SalView. It is designed to be tree-consistent across all surfaces without forking.