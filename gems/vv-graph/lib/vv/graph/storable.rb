# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "active_support/concern"
require "active_support/core_ext/class/attribute"
require "json"

module Vv; end

module Vv::Graph
  # PLAN_0.1.0 Phase D — per-model triple-emission DSL.
  # PLAN_0.2.0 Phase A — `on_subject` sub-blocks + literal-string
  # predicate values.
  # PLAN_0.2.0 Phase B — `each` blocks for collection iteration +
  # multi-value predicates (one triple per collection element;
  # multi-value when the predicate IRI is constant across items).
  #
  # ActiveSupport::Concern that takes a `triples do ... end` block
  # declaring a `subject` lambda + an ordered list of
  # `triple(predicate, value_lambda, if: optional_guard_lambda)`
  # entries. `on_subject` blocks declare additional emissions on a
  # different subject IRI; they share the same lifecycle hooks.
  #
  #   class Product < ApplicationRecord
  #     include Vv::Graph::Storable
  #
  #     triples do
  #       subject       -> { "urn:mm:product:#{sku}" }
  #       triple "schema:name",     -> { name }
  #       triple "schema:category", -> { category }
  #       triple "schema:gtin",     -> { gtin }, if: -> { gtin.present? }
  #
  #       on_subject -> { "urn:mm:folder:category:#{category}" } do
  #         triple "rdf:type",    "<urn:mm:CategoryFolder>"
  #         triple "schema:name", -> { category.titleize }
  #       end
  #     end
  #   end
  #
  # The `triple` second argument may be a lambda (evaluated in
  # instance scope each emission) or a literal value (constant
  # across emissions). Operators wanting an IRI object pass a
  # pre-wrapped `"<urn:...>"`-shaped string; otherwise the value
  # routes through `TermSerializer.object` for type dispatch.
  #
  # ## Idempotency contract
  #
  # `after_save` runs on both create and update. To prevent stale
  # values accumulating, every emission is read-replace per
  # predicate: SELECT any current value(s) for `<subject> <predicate>`,
  # DELETE each, then INSERT the new value. Re-saving an unchanged
  # record produces identical triples — Oxigraph set semantics make
  # the round-trip a no-op at the store level (though it still costs
  # a SELECT + DELETE + INSERT). Optimising via dirty-tracking is
  # post-0.1.0; v0.3.0's `:sparql_update` dispatch mode collapses
  # the round-trips when the engine surface is present.
  #
  # ## Failure mode
  #
  # `Vv::Graph::Sparql.*` calls never raise — they return refusal
  # envelopes. v0.1.0 silently swallows refusals during emission;
  # callers wanting strict mode set `MM_SEMANTICA_STRICT=1` to
  # surface them as `RuntimeError`. Matches the
  # `MM_SEMANTICA_SOFT_FAIL` boot pattern in spirit (env-toggled
  # discipline, default = lenient during the substrate's interim
  # window).
  # SOLE GO-FORWARD graph DSL (owner decision 2026-08-11; ADR StorableBootSafe).
  # Vv::Graph::TripleModel is DEPRECATED — existing TripleModel models migrate later,
  # plugin-stability-gated. Storable projects via Publisher#schedule (S1 seam);
  # server = Publisher::Immediate (drain-now); plugin = Publisher::BootAware (S3).
  #
  # Prior 0.20.0 note claimed TripleModel superseded Storable; that is reversed.
  module Storable
    extend ActiveSupport::Concern

    # PLAN_0.3.0 Phase B + C — dispatch-mode ladder.
    #
    # Three lifecycle implementations:
    #
    #   :sparql_update — engine ≥ 0.5.0 (`sparql_update` scalar
    #                    present). Each predicate replacement is a
    #                    single DELETE/INSERT WHERE round-trip.
    #   :bulk          — engine ≥ 0.4.0 (`rdf_insert_many` present,
    #                    no `sparql_update`). PLAN_0.4.0 fills in the
    #                    actual implementation; until then this rung
    #                    of the ladder falls through to :per_call.
    #   :per_call      — v0.2.0 baseline. SELECT + DELETE DATA + INSERT
    #                    DATA per predicate, one round-trip each.
    #
    # Operators force a mode via `MM_SEMANTICA_DISPATCH_MODE=...` for
    # predictable behaviour across upgrades. The probe runs once on
    # first call + caches; reset via `dispatch_mode_reset!` (specs).
    #
    # PLAN_0.6.0 Phase D — concurrency note. Under engine ≥ 0.2.0
    # the store is process-wide. Concurrent writes to the same
    # (subject, predicate) from different threads are atomic under
    # `:sparql_update` (the engine's Oxigraph store handles the
    # DELETE/INSERT WHERE in one call); `:bulk` and `:per_call` race.
    # Recommend `MM_SEMANTICA_DISPATCH_MODE=sparql_update` for
    # multi-threaded write workloads.
    ENV_DISPATCH_MODE = "MM_SEMANTICA_DISPATCH_MODE"

    DISPATCH_MODES = [:sparql_update, :bulk, :per_call].freeze

    class << self
      def dispatch_mode
        @dispatch_mode ||= detect_dispatch_mode
      end

      def dispatch_mode_reset!
        @dispatch_mode = nil
      end

      private

      def detect_dispatch_mode
        forced = ENV[ENV_DISPATCH_MODE]
        if forced && !forced.empty?
          sym = forced.to_sym
          return sym if DISPATCH_MODES.include?(sym)
        end

        # Oxigraph (Vv::Graph::OxirsBackend — the only backend) executes SPARQL
        # 1.1 UPDATE atomically, so the single-round-trip DELETE/INSERT WHERE
        # path is always available. No engine probe needed; the retired
        # sqlite-sparql extension + Vv::Graph::Loader are gone.
        :sparql_update
      end
    end

    included do
      class_attribute :semantica_triples_declaration, instance_accessor: false
    end

    class_methods do
      def triples(&block)
        raise ArgumentError, "triples requires a block" unless block

        recorder = Recorder.new
        recorder.instance_eval(&block)
        declaration = recorder.finalize!

        self.semantica_triples_declaration = declaration
        # OPT-IN projection (was opt-out): declaring the triple SHAPE no longer
        # wires per-save graph emit. The graph EXTENDS SQL (semantic edges,
        # federation) rather than replicating every AR row into SPARQL on every
        # save -- that per-save DELETE+INSERT was a write-amplification / wedge
        # source (esp. hot-path models like Mm::ShellInvocation). Models that
        # need the graph kept live on write opt in with `project_on_save!`;
        # others project explicitly (e.g. project_graph!) or on demand via
        # `semantica_emit_triples!`.
      end

      # Opt-in: wire per-save graph projection. Call AFTER `triples do ... end`
      # in models whose named graph must stay live on every write. Idempotent
      # (ActiveSupport de-dups identical method-symbol callbacks).
      #
      # S1+S2 (ADR StorableBootSafe): create/update/destroy go through
      # `Vv::Graph.publisher.schedule(...)`. Default Publisher::Immediate
      # upserts ProjectionJob then drains now (atomic-replace / tombstone).
      def project_on_save!
        return unless respond_to?(:after_save)
        after_save    :semantica_schedule_projection!
        after_destroy :semantica_schedule_retraction!
      end
    end

    # S1/S2 seam entry: schedule a projection obligation for this row.
    # Immediate drains now; BootAware (S3) may return :deferred.
    def semantica_schedule_projection!
      return unless self.class.semantica_triples_declaration
      return if id.nil?

      ::Vv::Graph.publisher.schedule(
        ref: ::Vv::Graph::Ref.new(self.class.name, id),
        generation: semantica_projection_generation,
        action: :project,
        record: self,
      )
    end

    # S2 tombstone: schedule retract of PRIMARY subject only (shared
    # on_subject subjects stay additive — do not wipe siblings).
    def semantica_schedule_retraction!
      return unless self.class.semantica_triples_declaration

      ::Vv::Graph.publisher.schedule(
        ref: ::Vv::Graph::Ref.new(self.class.name, id),
        generation: semantica_projection_generation,
        action: :retract,
        record: self,
      )
    end

    # Monotonic generation for the projection outbox.
    # Prefer graph_generation column; else lock_version; else usec clock.
    def semantica_projection_generation
      if respond_to?(:graph_generation) && !graph_generation.nil?
        Integer(graph_generation)
      elsif respond_to?(:lock_version) && !lock_version.nil?
        Integer(lock_version)
      else
        (Time.now.to_f * 1_000_000).to_i
      end
    end

    def semantica_primary_subject_iri
      decl = self.class.semantica_triples_declaration
      return nil unless decl

      instance_exec(&decl.subject_lambda)
    end

    def semantica_graph_iri
      self.class.semantica_triples_declaration&.graph_iri
    end

    # S2 atomic-replace emission (topology-preserving).
    # PRIMARY subject: DELETE all (s,?p,?o) then INSERT current triples
    # (two separate Sparql.execute calls — never combined). Shared
    # on_subject subjects remain ADDITIVE (per-predicate replace only).
    def semantica_emit_triples!
      decl = self.class.semantica_triples_declaration
      return unless decl

      graph = decl.graph_iri
      subject_iri  = instance_exec(&decl.subject_lambda)
      subject_term = TermSerializer.iri(subject_iri)

      # 1) Clear primary subject (separate DELETE executes)
      cleared = clear_primary_subject!(subject_term, graph)
      return cleared if failed_envelope?(cleared)

      # 2) Insert current primary + each-block triples under primary subject
      inserted = insert_primary_predicates_(subject_iri, subject_term, decl.predicates, graph)
      return inserted if failed_envelope?(inserted)
      decl.each_blocks.each do |each_block|
        r = insert_each_block_(subject_term, each_block, graph)
        return r if failed_envelope?(r)
      end

      # 3) on_subject SHARED subjects — ADDITIVE, never subject-clear
      decl.on_subject_blocks.each do |block|
        r = semantica_emit_for_(block.subject_lambda, block.predicates, graph)
        return r if failed_envelope?(r)
      end
      true
    end

    # Full primary-subject retract (tombstone). Does NOT touch on_subject
    # shared subjects (category folders etc. survive sibling deletes).
    def semantica_retract_primary_subject!
      decl = self.class.semantica_triples_declaration
      return unless decl

      graph = decl.graph_iri
      subject_iri  = instance_exec(&decl.subject_lambda)
      subject_term = TermSerializer.iri(subject_iri)

      # Concrete annotation subjects (current parent values) — more reliable
      # than FILTER(isTRIPLE) on some Oxigraph builds.
      decl.predicates.each do |pred|
        next if pred.annotations.nil? || pred.annotations.empty?
        value = begin
          next if pred.if_lambda && !instance_exec(&pred.if_lambda)
          instance_exec(&pred.value_lambda)
        rescue StandardError
          nil
        end
        next if value.nil?

        quoted = ::Vv::Graph::Sparql.quoted_triple(subject_iri, pred.iri, value)
        quoted_term = TermSerializer.iri(quoted)
        rdf_star_annotation_delete(
          "DELETE { #{quoted_term} ?ap ?ao } WHERE { #{quoted_term} ?ap ?ao }",
          graph: graph,
        )
        semantica_retract_orphan_annotations_(subject_iri, pred, graph)
      end

      cleared = clear_primary_subject!(subject_term, graph)
      return cleared if failed_envelope?(cleared)
      true
    end

    # Backward-compatible name: primary-only retract (S2 semantics).
    # NOTE: previously also retracted on_subject; that wiped shared
    # subjects. S2 deliberately only clears the primary subject.
    def semantica_retract_triples!
      semantica_retract_primary_subject!
    end

    # Class-level subject clear used by Immediate post-crash tombstone.
    def self.clear_subject_iri!(subject_iri, graph = nil)
      subject_term = TermSerializer.iri(subject_iri)
      rdf_star_annotation_delete(
        "DELETE { ?__t ?__ap ?__ao } WHERE { " \
        "?__t ?__ap ?__ao . " \
        "FILTER(isTRIPLE(?__t) && SUBJECT(?__t) = #{subject_term}) }",
        graph: graph,
      )
      direct = ::Vv::Graph::Sparql.execute(
        "DELETE { #{subject_term} ?p ?o } WHERE { #{subject_term} ?p ?o }",
        graph: graph,
      )
      return direct if failed_envelope?(direct)
      true
    end

    # Any {ok:false} SPARQL envelope fails the emit. Exemption is a CALL
    # SITE (rdf_star_annotation_delete), not a reason allowlist.
    def self.failed_envelope?(env)
      env.is_a?(::Hash) && env[:ok] == false
    end

    # Oxigraph rejects DELETE of RDF-star quoted-triple subjects
    # (INSERT/SELECT work; parent-subject DELETE works; isTRIPLE FILTER
    # is a no-op). This is that call site: swallow the engine-limited
    # refusal so the rest of emit/retract still runs. GRAPH unreachable
    # is NOT engine-limited -- return that envelope so a retract-only
    # path cannot report success against a dead store (gap 95).
    def self.rdf_star_annotation_delete(query, graph: nil)
      env = ::Vv::Graph::Sparql.execute(query, graph: graph)
      return env if graph_unreachable?(env)
      true
    end

    def self.graph_unreachable?(env)
      env.is_a?(::Hash) && env[:ok] == false && env[:reason] == :graph_unreachable
    end

    private

    # S2: clear ALL triples for primary subject S in graph G.
    # Separate Sparql.execute calls — NEVER combine DELETE+INSERT
    # in one execute (known dispatcher bug).
    def failed_envelope?(env)
      ::Vv::Graph::Storable.failed_envelope?(env)
    end

    def rdf_star_annotation_delete(query, graph: nil)
      ::Vv::Graph::Storable.rdf_star_annotation_delete(query, graph: graph)
    end

    def quoted_triple_term?(term)
      term.to_s.lstrip.start_with?("<<")
    end

    def sparql_delete(query, graph:, subject_term:, context:)
      if quoted_triple_term?(subject_term)
        env = rdf_star_annotation_delete(query, graph: graph)
        return env if failed_envelope?(env)
        return { ok: true }
      end
      env = ::Vv::Graph::Sparql.execute(query, graph: graph)
      raise_if_strict(env, context)
      env
    end

    def clear_primary_subject!(subject_term, graph = nil)
      # 1) Annotations whose subject is a quoted triple with S as SUBJECT(?t).
      #    SPARQL-star FILTER form — more reliable than nesting << S ?p ?o >>
      #    patterns across Oxigraph versions. Engine-limited DELETE: do not
      #    fail the emit on this site's envelope.
      rdf_star_annotation_delete(
        "DELETE { ?__t ?__ap ?__ao } WHERE { " \
        "?__t ?__ap ?__ao . " \
        "FILTER(isTRIPLE(?__t) && SUBJECT(?__t) = #{subject_term}) }",
        graph: graph,
      )
      # 2) Per-predicate orphan annotation retract (legacy path)
      decl = self.class.semantica_triples_declaration
      if decl
        begin
          subject_iri = instance_exec(&decl.subject_lambda)
          decl.predicates.each do |pred|
            next if pred.annotations.nil? || pred.annotations.empty?
            semantica_retract_orphan_annotations_(subject_iri, pred, graph)
          end
        rescue StandardError
          # ignore
        end
      end
      # 3) All direct (s, p, o) under the primary subject
      direct = ::Vv::Graph::Sparql.execute(
        "DELETE { #{subject_term} ?p ?o } WHERE { #{subject_term} ?p ?o }",
        graph: graph,
      )
      return direct if failed_envelope?(direct)
      true
    end

    # Insert-only primary predicates (caller already cleared the subject).
    def insert_primary_predicates_(subject_iri, subject_term, predicates, graph)
      predicates.each do |pred|
        next if pred.if_lambda && !instance_exec(&pred.if_lambda)
        value = instance_exec(&pred.value_lambda)
        next if value.nil?

        inserted = insert_predicate_set!(
          subject_term,
          TermSerializer.predicate(pred.iri),
          [TermSerializer.object(value)],
          graph,
        )
        return inserted if failed_envelope?(inserted)
        # Annotations after primary clear: INSERT only (never combined DELETE+INSERT).
        annotated = insert_annotations_(subject_iri, pred, value, graph)
        return annotated if failed_envelope?(annotated)
      end
      true
    end

    # Insert-only annotations on a quoted-triple subject (post-clear path).
    def insert_annotations_(parent_subject_iri, pred, parent_value, graph)
      return if pred.annotations.nil? || pred.annotations.empty?

      quoted_subject = ::Vv::Graph::Sparql.quoted_triple(
        parent_subject_iri, pred.iri, parent_value,
      )
      quoted_term = TermSerializer.iri(quoted_subject)

      pred.annotations.each do |ann|
        next if ann.if_lambda && !instance_exec(&ann.if_lambda)
        ann_value = instance_exec(&ann.value_lambda)
        next if ann_value.nil?

        inserted = insert_predicate_set!(
          quoted_term,
          TermSerializer.predicate(ann.predicate_iri),
          [TermSerializer.object(ann_value)],
          graph,
        )
        return inserted if failed_envelope?(inserted)
      end
      true
    end

    # Insert-only each-block multi-values under primary subject.
    def insert_each_block_(subject_term, each_block, graph)
      collection = instance_exec(&each_block.collection_lambda)
      return if collection.nil? || (collection.respond_to?(:empty?) && collection.empty?)

      buffer = collect_each_predicates_(collection, each_block)
      by_predicate = Hash.new { |h, k| h[k] = [] }
      buffer.each do |pred|
        next if pred.if_lambda && !instance_exec(&pred.if_lambda)
        value = instance_exec(&pred.value_lambda)
        next if value.nil?
        by_predicate[pred.iri] << TermSerializer.object(value)
      end
      by_predicate.each do |iri, new_object_terms|
        inserted = insert_predicate_set!(
          subject_term,
          TermSerializer.predicate(iri),
          new_object_terms,
          graph,
        )
        return inserted if failed_envelope?(inserted)
      end
      true
    end

    # Two separate executes: DELETE WHERE (s,p,?o) then INSERT DATA.
    # Never combine DELETE+INSERT in one execute (dispatcher bug).
    # Used after clear_primary_subject! and for annotation slots.
    def insert_predicate_set!(subject_term, predicate_term, new_object_terms, graph = nil)
      # Retract current (s,p,*) so re-save is idempotent even if outer
      # subject-clear missed RDF-star annotation subjects.
      del = sparql_delete(
        "DELETE { #{subject_term} #{predicate_term} ?o } " \
        "WHERE  { #{subject_term} #{predicate_term} ?o }",
        graph: graph,
        subject_term: subject_term,
        context: "DELETE WHERE #{predicate_term}",
      )
      return del if failed_envelope?(del)

      return { ok: true, count: 0 } if new_object_terms.nil? || new_object_terms.empty?

      body = new_object_terms.map { |o| "#{subject_term} #{predicate_term} #{o} ." }.join("\n")
      result = ::Vv::Graph::Sparql.execute("INSERT DATA { #{body} }", graph: graph)
      raise_if_strict(result, "INSERT DATA #{predicate_term}")
      result
    end

    # on_subject ADDITIVE path — per-predicate read-replace (no subject clear).
    def semantica_emit_for_(subject_lambda, predicates, graph = nil)
      subject_iri  = instance_exec(&subject_lambda)
      subject_term = TermSerializer.iri(subject_iri)
      predicates.each do |pred|
        next if pred.if_lambda && !instance_exec(&pred.if_lambda)
        value = instance_exec(&pred.value_lambda)
        predicate_term = TermSerializer.predicate(pred.iri)

        if value.nil?
          retracted = retract_predicate!(subject_term, predicate_term, graph)
          return retracted if failed_envelope?(retracted)
          semantica_retract_orphan_annotations_(subject_iri, pred, graph)
          next
        end

        semantica_retract_orphan_annotations_(subject_iri, pred, graph)

        replaced = replace_predicate!(
          subject_term,
          predicate_term,
          TermSerializer.object(value),
          graph,
        )
        return replaced if failed_envelope?(replaced)

        annotated = semantica_emit_annotations_(subject_iri, pred, value, graph)
        return annotated if failed_envelope?(annotated)
      end
      true
    end

    def semantica_retract_for_(subject_lambda, predicates, graph = nil)
      subject_iri  = instance_exec(&subject_lambda)
      subject_term = TermSerializer.iri(subject_iri)
      predicates.each do |pred|
        retract_predicate!(subject_term, TermSerializer.predicate(pred.iri), graph)
        semantica_retract_orphan_annotations_(subject_iri, pred, graph)
      end
    end

    # PLAN_0.8.0 Phase B — emit one triple per annotation declared
    # on `pred`. Annotation subject = the quoted-triple form of the
    # just-emitted parent. Annotation predicate = the operator's
    # `annotate` IRI. Annotation object = the evaluator's result.
    #
    # Each annotation uses `replace_predicate!` so re-saves are
    # idempotent (same parent value + same annotation value = no-op).
    def semantica_emit_annotations_(parent_subject_iri, pred, parent_value, graph)
      return if pred.annotations.nil? || pred.annotations.empty?

      quoted_subject = ::Vv::Graph::Sparql.quoted_triple(
        parent_subject_iri, pred.iri, parent_value,
      )
      quoted_term = TermSerializer.iri(quoted_subject)

      pred.annotations.each do |ann|
        next if ann.if_lambda && !instance_exec(&ann.if_lambda)
        ann_value = instance_exec(&ann.value_lambda)
        next if ann_value.nil?

        replaced = replace_predicate!(
          quoted_term,
          TermSerializer.predicate(ann.predicate_iri),
          TermSerializer.object(ann_value),
          graph,
        )
        return replaced if failed_envelope?(replaced)
      end
      true
    end

    # PLAN_0.8.0 Phase B — retract every annotation on the parent's
    # quoted-triple subject. Oxigraph can be unreliable on
    # DELETE WHERE with quoted-triple subjects; SELECT then DELETE DATA
    # with concrete terms is the portable path.
    def semantica_retract_orphan_annotations_(parent_subject_iri, pred, graph)
      return if pred.annotations.nil? || pred.annotations.empty?

      subject_iri_form   = TermSerializer.iri(parent_subject_iri)
      predicate_iri_form = TermSerializer.predicate(pred.iri)

      # Find concrete parent objects still (or previously) present.
      objs = ::Vv::Graph::Sparql.select(
        "SELECT ?o WHERE { #{subject_iri_form} #{predicate_iri_form} ?o }",
        graph: graph,
      )
      object_terms = []
      if objs.is_a?(Hash) && objs[:ok]
        objs[:results].each { |row| object_terms << row["o"] if row["o"] }
      end
      # Also try current instance value (destroy/update path).
      begin
        cur = instance_exec(&pred.value_lambda)
        object_terms << TermSerializer.object(cur) unless cur.nil?
      rescue StandardError
        # ignore
      end
      object_terms.uniq!

      object_terms.each do |o_term|
        # Rebuild quoted subject. o_term may already be N-Triples form.
        qt_term =
          if o_term.to_s.start_with?("<<")
            o_term
          else
            # o_term is already a serialized object term (literal or IRI)
            "<< #{subject_iri_form} #{predicate_iri_form} #{o_term} >>"
          end
        anns = ::Vv::Graph::Sparql.select(
          "SELECT ?ap ?ao WHERE { #{qt_term} ?ap ?ao }",
          graph: graph,
        )
        next unless anns.is_a?(Hash) && anns[:ok]

        anns[:results].each do |row|
          ap = row["ap"]
          ao = row["ao"]
          next if ap.nil? || ao.nil?

          rdf_star_annotation_delete(
            "DELETE DATA { #{qt_term} #{ap} #{ao} . }",
            graph: graph,
          )
        end
      end
    end

    # PLAN_0.2.0 Phase B emission: walk the collection, accumulate
    # (iri, value) pairs, then for each unique predicate IRI retract
    # all current values for (subject, predicate) and insert the fresh set.
    #
    # Caveats documented in the plan:
    # - When the collection is empty this save, the predicate set is empty,
    #   so no retraction fires; stale triples from a prior non-empty save
    #   persist. v0.2.0 ships this limitation.
    # - Values returning nil are *skipped* (not emitted as nil-retraction);
    #   the surrounding read-replace per-predicate already cleared the slot.
    def semantica_emit_each_block_(subject_lambda, each_block, graph = nil)
      subject_term = TermSerializer.iri(instance_exec(&subject_lambda))
      collection = instance_exec(&each_block.collection_lambda)
      return if collection.nil? || (collection.respond_to?(:empty?) && collection.empty?)

      buffer = collect_each_predicates_(collection, each_block)

      by_predicate = Hash.new { |h, k| h[k] = [] }
      buffer.each do |pred|
        next if pred.if_lambda && !instance_exec(&pred.if_lambda)
        value = instance_exec(&pred.value_lambda)
        next if value.nil?
        by_predicate[pred.iri] << TermSerializer.object(value)
      end

      by_predicate.each do |iri, new_object_terms|
        replace_predicate_set!(
          subject_term,
          TermSerializer.predicate(iri),
          new_object_terms,
          graph,
        )
      end
    end

    # Destroy-path counterpart. Walks the collection one last time to
    # enumerate the predicate set; retracts each via dispatch-mode's
    # retract helper. If the collection is empty at destroy time, no
    # retraction fires — stale triples from prior saves survive.
    def semantica_retract_each_block_(subject_lambda, each_block, graph = nil)
      subject_term = TermSerializer.iri(instance_exec(&subject_lambda))
      collection = instance_exec(&each_block.collection_lambda)
      return if collection.nil? || (collection.respond_to?(:empty?) && collection.empty?)

      buffer = collect_each_predicates_(collection, each_block)
      buffer.map(&:iri).uniq.each do |iri|
        retract_predicate!(subject_term, TermSerializer.predicate(iri), graph)
      end
    end

    # Run the each block once per collection item, accumulating
    # Predicate records into a shared buffer.
    def collect_each_predicates_(collection, each_block)
      buffer = []
      collection.each do |item|
        item_recorder = EachItemRecorder.new(buffer)
        item_recorder.instance_exec(item, &each_block.block_proc)
      end
      buffer
    end

    def replace_predicate!(subject_term, predicate_term, new_object_term, graph = nil)
      replace_predicate_set!(subject_term, predicate_term, [new_object_term], graph)
    end

    def retract_predicate!(subject_term, predicate_term, graph = nil)
      if @semantica_bulk_buffer
        @semantica_bulk_buffer.add(subject_term, predicate_term, [], graph)
        return { ok: true }
      end

      case ::Vv::Graph::Storable.dispatch_mode
      when :sparql_update
        retract_predicate_via_update!(subject_term, predicate_term, graph)
      else
        retract_predicate_per_call!(subject_term, predicate_term, graph)
      end
    end

    # PLAN_0.3.0 Phase B — replace a (subject, predicate) slot with
    # a (possibly multi-value) set of new object terms in one engine
    # round-trip when sparql_update is available; otherwise fall
    # back to the per-call SELECT+DELETE+INSERT path.
    #
    # PLAN_0.4.0 Phase B — when an outer bulk buffer is active
    # (:bulk dispatch mode), record into the buffer instead of
    # executing; flush_emit! issues one bulk_delete + one
    # bulk_insert at the end of the save.
    def replace_predicate_set!(subject_term, predicate_term, new_object_terms, graph = nil)
      if @semantica_bulk_buffer
        @semantica_bulk_buffer.add(subject_term, predicate_term, new_object_terms, graph)
        return { ok: true }
      end

      case ::Vv::Graph::Storable.dispatch_mode
      when :sparql_update
        replace_predicate_set_via_update!(subject_term, predicate_term, new_object_terms, graph)
      else
        replace_predicate_set_per_call!(subject_term, predicate_term, new_object_terms, graph)
      end
    end

    # PLAN_0.4.0 Phase B — bulk-mode lifecycle wrapper. Captures
    # replace/retract operations across primary + on_subject + each
    # blocks; flushes via one combined bulk_delete (all current
    # values for affected (s, p, graph) keys) + one combined
    # bulk_insert (all new values). 2 + N round-trips per save where
    # N = unique (s, p, graph) keys: the engine SELECT count
    # dominates wall-clock for records with many predicates; the
    # bulk_delete + bulk_insert are constant.
    def with_bulk_buffer_if_bulk_mode_
      if ::Vv::Graph::Storable.dispatch_mode == :bulk
        prior = @semantica_bulk_buffer
        @semantica_bulk_buffer = BulkEmitBuffer.new
        begin
          yield
          flush = @semantica_bulk_buffer.flush!
          raise_if_strict(flush, "bulk flush") if flush.is_a?(Hash) && !flush[:ok]
        ensure
          @semantica_bulk_buffer = prior
        end
      else
        yield
      end
    end

    def replace_predicate_set_via_update!(s, p, new_objects, graph)
      insert_clause =
        if new_objects.empty?
          ""
        else
          new_objects.map { |o| "#{s} #{p} #{o} ." }.join(" ")
        end

      update =
        if insert_clause.empty?
          "DELETE { #{s} #{p} ?o } WHERE { #{s} #{p} ?o }"
        else
          "DELETE { #{s} #{p} ?o }\n" \
            "INSERT { #{insert_clause} }\n" \
            "WHERE  { OPTIONAL { #{s} #{p} ?o } }"
        end

      if quoted_triple_term?(s)
        deleted = rdf_star_annotation_delete(
          "DELETE { #{s} #{p} ?o } WHERE { #{s} #{p} ?o }",
          graph: graph,
        )
        return deleted if failed_envelope?(deleted)
        return { ok: true, count: 0 } if insert_clause.empty?
        result = ::Vv::Graph::Sparql.execute(
          "INSERT DATA { #{new_objects.map { |o| "#{s} #{p} #{o} ." }.join("\n")} }",
          graph: graph,
        )
        raise_if_strict(result, "INSERT DATA #{p}")
        return result
      end

      result = ::Vv::Graph::Sparql.execute(update, graph: graph)
      raise_if_strict(result, "DELETE/INSERT WHERE #{p}")
      result
    end

    def replace_predicate_set_per_call!(s, p, new_objects, graph)
      retract_predicate_per_call!(s, p, graph)
      return { ok: true, count: 0 } if new_objects.empty?

      body = new_objects.map { |o| "#{s} #{p} #{o} ." }.join("\n")
      result = ::Vv::Graph::Sparql.execute("INSERT DATA { #{body} }", graph: graph)
      raise_if_strict(result, "INSERT DATA #{p}")
      result
    end

    def retract_predicate_via_update!(s, p, graph)
      sparql_delete(
        "DELETE { #{s} #{p} ?o } WHERE { #{s} #{p} ?o }",
        graph: graph,
        subject_term: s,
        context: "DELETE WHERE #{p}",
      )
    end

    def retract_predicate_per_call!(s, p, graph)
      current = ::Vv::Graph::Sparql.select(
        "SELECT ?o WHERE { #{s} #{p} ?o }",
        graph: graph,
      )
      return current unless current[:ok]

      current[:results].each do |row|
        old_o = row["o"]
        next if old_o.nil? || old_o.empty?
        del = sparql_delete(
          "DELETE DATA { #{s} #{p} #{old_o} . }",
          graph: graph,
          subject_term: s,
          context: "DELETE DATA #{p}",
        )
        return del if failed_envelope?(del)
      end
      current
    end

    def raise_if_strict(envelope, context)
      return if envelope[:ok]
      return unless ENV["MM_SEMANTICA_STRICT"] == "1"
      raise "Vv::Graph::Storable #{context} refused: #{envelope[:reason]} — #{envelope[:because]}"
    end

    # ── Bulk emit buffer (PLAN_0.4.0 Phase B) ───────────────────

    # Captures replace/retract intents across a single save,
    # flushes via one bulk_delete (current values) + one
    # bulk_insert (new values). add(s_term, p_term, new_objs, graph)
    # appends an entry; an entry with an empty new_objs array is a
    # pure retract.
    #
    # Group key is (subject_term, predicate_term, graph) so that
    # multiple adds to the same slot (e.g., from primary +
    # on_subject blocks accidentally touching the same predicate)
    # union their new objects.
    class BulkEmitBuffer
      Entry = Struct.new(:subject_term, :predicate_term, :new_objects, :graph) do
        def key
          [subject_term, predicate_term, graph]
        end
      end

      def initialize
        @entries = []
      end

      def add(subject_term, predicate_term, new_object_terms, graph)
        @entries << Entry.new(subject_term, predicate_term, new_object_terms.dup, graph)
      end

      def flush!
        return { ok: true } if @entries.empty?

        grouped = Hash.new { |h, k| h[k] = [] }
        @entries.each { |e| grouped[e.key].concat(e.new_objects) }

        delete_rows = []
        grouped.each_key do |(s_term, p_term, graph)|
          current = ::Vv::Graph::Sparql.select(
            "SELECT ?o WHERE { #{s_term} #{p_term} ?o }",
            graph: graph,
          )
          next unless current[:ok]
          current[:results].each do |row|
            o_raw = row["o"]
            next if o_raw.nil? || o_raw.empty?
            delete_rows << build_row_(s_term, p_term, o_raw, graph)
          end
        end

        insert_rows = []
        grouped.each do |(s_term, p_term, graph), new_objects|
          new_objects.each do |o_term|
            insert_rows << build_row_(s_term, p_term, o_term, graph)
          end
        end

        unless delete_rows.empty?
          del = ::Vv::Graph::Sparql.bulk_delete(delete_rows, raw: true)
          return del unless del[:ok]
        end
        unless insert_rows.empty?
          ins = ::Vv::Graph::Sparql.bulk_insert(insert_rows, raw: true)
          return ins unless ins[:ok]
        end
        { ok: true }
      end

      private

      def build_row_(s_term, p_term, o_term, graph)
        s_bare = bare_(s_term)
        p_bare = bare_(p_term)
        o_engine = o_term.start_with?("<") ? bare_(o_term) : o_term
        if graph
          [s_bare, p_bare, o_engine, graph]
        else
          [s_bare, p_bare, o_engine]
        end
      end

      def bare_(term)
        return term unless term.is_a?(String) && term.start_with?("<") && term.end_with?(">")
        term[1..-2]
      end
    end

    # ── DSL recorder ────────────────────────────────────────────

    Declaration = Struct.new(:subject_lambda, :predicates, :on_subject_blocks, :each_blocks, :graph_iri) do
      def initialize(subject_lambda:, predicates:, on_subject_blocks: [], each_blocks: [], graph_iri: nil)
        super(subject_lambda, predicates, on_subject_blocks, each_blocks, graph_iri)
      end
    end

    # PLAN_0.8.0 Phase B — `annotate` block on a `triple` declaration
    # populates `annotations` with one Annotation per annotate call.
    # Empty array when the triple has no `annotate` block (the
    # common case).
    Predicate = Struct.new(:iri, :value_lambda, :if_lambda, :annotations) do
      def initialize(iri:, value_lambda:, if_lambda: nil, annotations: [])
        super(iri, value_lambda, if_lambda, annotations.freeze)
      end
    end

    # PLAN_0.8.0 Phase B — single annotation inside a `triple … do
    # annotate p, ->{...}; end` block. The validator's evaluator
    # is called at emission time with the parent triple's resolved
    # (s, p, o) so the annotation can attach to a
    # `Sparql.quoted_triple(s, p, o)` subject.
    Annotation = Struct.new(:predicate_iri, :value_lambda, :if_lambda) do
      def initialize(predicate_iri:, value_lambda:, if_lambda: nil)
        super(predicate_iri, value_lambda, if_lambda)
      end
    end

    OnSubjectBlock = Struct.new(:subject_lambda, :predicates) do
      def initialize(subject_lambda:, predicates:)
        super(subject_lambda, predicates)
      end
    end

    # PLAN_0.2.0 Phase B — per-collection block. block_proc receives
    # an item as its block param; inside the block, `triple` records
    # a (per-item interpolated IRI, value lambda closing over item).
    # The block_proc isn't evaluated at declaration time; emission
    # re-runs it once per current-collection item.
    EachBlock = Struct.new(:collection_lambda, :block_proc) do
      def initialize(collection_lambda:, block_proc:)
        super(collection_lambda, block_proc)
      end
    end

    # Shared triple-recording between the top-level Recorder and the
    # SubRecorder used inside `on_subject` blocks. Both maintain a
    # `@predicates` array; `triple` appends to it.
    module TripleRecording
      # triple "schema:name", -> { name }
      # triple "schema:gtin", -> { gtin }, if: -> { gtin.present? }
      # triple "rdf:type",    "<urn:mm:CategoryFolder>"          # literal value
      #
      # PLAN_0.8.0 Phase B — optional block with `annotate` calls
      # attaches RDF-star annotations to the parent triple:
      #
      #   triple "schema:gtin", -> { gtin } do
      #     annotate "mm:reportedBy", -> { "urn:mm:user:#{updater_id}" }
      #     annotate "mm:reportedAt", -> { updated_at.iso8601 }
      #   end
      #
      # The parent triple emits + each annotation emits a triple
      # whose subject is the quoted-triple form of the parent.
      # Parent `if:` false skips both the parent and all
      # annotations. Update-time changes to the parent object
      # orphan the prior quoted-triple subject — that's
      # SPARQL-star referential opacity semantics (StarExts.md §3).
      def triple(iri, value_or_lambda, **opts, &block)
        annotations =
          if block
            sub = AnnotationRecorder.new
            sub.instance_eval(&block)
            sub.annotations
          else
            []
          end
        @predicates << Predicate.new(
          iri: iri,
          value_lambda: as_callable(value_or_lambda),
          if_lambda: opts[:if],
          annotations: annotations,
        )
      end

      # Wrap a literal value in a lambda so the emission path stays
      # uniform. Callables (Procs, lambdas) pass through.
      def as_callable(value_or_lambda)
        if value_or_lambda.respond_to?(:call)
          value_or_lambda
        else
          captured = value_or_lambda
          -> { captured }
        end
      end
    end

    # PLAN_0.8.0 Phase B — recorder used inside a `triple … do …
    # end` block to capture `annotate` calls.
    class AnnotationRecorder
      attr_reader :annotations

      def initialize
        @annotations = []
      end

      # annotate "mm:reportedBy", -> { user_iri }
      # annotate "mm:confidence", -> { score }, if: -> { score.present? }
      def annotate(predicate_iri, value_or_lambda, **opts)
        @annotations << Annotation.new(
          predicate_iri: predicate_iri,
          value_lambda:  as_callable_annotation(value_or_lambda),
          if_lambda:     opts[:if],
        )
      end

      private

      def as_callable_annotation(value_or_lambda)
        if value_or_lambda.respond_to?(:call)
          value_or_lambda
        else
          captured = value_or_lambda
          -> { captured }
        end
      end
    end

    class SubRecorder
      include TripleRecording

      attr_reader :predicates

      def initialize
        @predicates = []
      end
    end

    # Per-collection-item recorder for `each` blocks. The block_proc
    # is instance_exec'd against an EachItemRecorder with the item
    # passed as the block param; inside the block, `triple` pushes
    # into a buffer shared across all items in the iteration.
    class EachItemRecorder
      include TripleRecording

      def initialize(buffer)
        @predicates = buffer
      end
    end

    class Recorder
      include TripleRecording

      def initialize
        @subject_lambda = nil
        @predicates = []
        @on_subject_blocks = []
        @each_blocks = []
        @graph_iri = nil
      end

      # subject -> { "urn:mm:product:#{sku}" }
      # subject { "urn:mm:product:#{sku}" }
      def subject(callable = nil, &block)
        @subject_lambda = callable || block
      end

      # PLAN_0.5.0 — declare the named graph every triple in the
      # block emits to. One graph per `triples do…end`; `on_subject`
      # and `each` blocks inherit it. Operators wanting cross-graph
      # emissions per record use `Sparql.execute` / `bulk_insert`
      # directly. Blank-node graphs refuse at the Sparql boundary
      # (REASON_INVALID_GRAPH); other invalid IRIs surface from the
      # engine's rdf_insert path.
      #
      #   triples do
      #     graph "urn:mm:graph:bhphoto"
      #     subject -> { "urn:mm:product:#{sku}" }
      #     # ...
      #   end
      def graph(name)
        @graph_iri = name
      end

      # on_subject -> { "urn:mm:folder:category:#{category}" } do
      #   triple "rdf:type",    "<urn:mm:CategoryFolder>"
      #   triple "schema:name", -> { category.titleize }
      # end
      def on_subject(subject_callable, &predicates_block)
        raise ArgumentError, "on_subject requires a predicates block" unless predicates_block
        raise ArgumentError, "on_subject requires a subject lambda" unless subject_callable

        sub = SubRecorder.new
        sub.instance_eval(&predicates_block)
        @on_subject_blocks << OnSubjectBlock.new(
          subject_lambda: subject_callable,
          predicates: sub.predicates.freeze,
        )
      end

      # each -> { product_specs } do |spec|
      #   triple "mm:#{spec.name.camelize(:lower)}", -> { spec.value }
      # end
      #
      # The block_proc is stored as-is; emission re-evaluates the
      # collection_lambda each save + runs the block once per item.
      def each(collection_callable, &predicates_block)
        raise ArgumentError, "each requires a predicates block" unless predicates_block
        raise ArgumentError, "each requires a collection lambda" unless collection_callable

        @each_blocks << EachBlock.new(
          collection_lambda: collection_callable,
          block_proc: predicates_block,
        )
      end

      def finalize!
        raise ArgumentError, "triples block requires `subject`" unless @subject_lambda
        Declaration.new(
          subject_lambda: @subject_lambda,
          predicates: @predicates.freeze,
          on_subject_blocks: @on_subject_blocks.freeze,
          each_blocks: @each_blocks.freeze,
          graph_iri: @graph_iri,
        ).freeze
      end
    end

    # ── N-Triples term serialization ────────────────────────────

    module TermSerializer
      XSD = "http://www.w3.org/2001/XMLSchema"

      module_function

      # Wraps a value as an N-Triples IRI: `<iri>`. Pass-through if
      # already wrapped. PLAN_0.8.0 Phase B: `Sparql::QuotedTriple`
      # markers serialise to `<< s p o >>` N-Triples-star form.
      def iri(value)
        return value.to_ntriples_star if value.is_a?(::Vv::Graph::Sparql::QuotedTriple)
        s = value.to_s
        return s if s.start_with?("<<") && s.end_with?(">>")
        return s if s.start_with?("<") && s.end_with?(">")
        "<#{s}>"
      end

      # Predicates are always IRIs.
      def predicate(value)
        iri(value)
      end

      # Object serialization — type-dispatch:
      #   String       → "escaped string" (literal)
      #   Integer      → "42"^^<xsd:integer>
      #   Float        → "3.14"^^<xsd:double>
      #   true/false   → "true"^^<xsd:boolean>
      #   Time/DateTime→ "iso8601"^^<xsd:dateTime>
      #   Date         → "iso8601"^^<xsd:date>
      #   Hash         → "{...JSON...}"^^<xsd:string>  (PLAN_0.2.0 Phase C)
      #   Array        → "[...JSON...]"^^<xsd:string>  (PLAN_0.2.0 Phase C)
      #   Other        → value.to_s as literal
      #
      # Operators wanting IRI objects pass already-wrapped strings
      # (e.g. `"<urn:other>"`) — those pass through unchanged.
      #
      # JSON dispatch uses xsd:string rather than rdf:JSON so the
      # engine's existing N-Triples parser round-trips the value
      # cleanly. Operators reading back via Sparql.select can
      # `JSON.parse` the resulting literal value.
      def object(value)
        return value.to_ntriples_star if value.is_a?(::Vv::Graph::Sparql::QuotedTriple)
        case value
        when String
          if value.start_with?("<<") && value.end_with?(">>")
            value
          elsif value.start_with?("<") && value.end_with?(">")
            value
          else
            literal(value)
          end
        when Integer
          typed_literal(value.to_s, "#{XSD}#integer")
        when Float
          typed_literal(value.to_s, "#{XSD}#double")
        when TrueClass, FalseClass
          typed_literal(value.to_s, "#{XSD}#boolean")
        when Hash, Array
          typed_literal(::JSON.generate(value), "#{XSD}#string")
        else
          temporal_or_literal(value)
        end
      end

      def temporal_or_literal(value)
        if value.respond_to?(:iso8601)
          datatype = value.respond_to?(:hour) ? "#{XSD}#dateTime" : "#{XSD}#date"
          typed_literal(value.iso8601, datatype)
        else
          literal(value.to_s)
        end
      end

      def literal(string)
        %("#{escape_literal(string)}")
      end

      def typed_literal(value, datatype_iri)
        %("#{escape_literal(value)}"^^<#{datatype_iri}>)
      end

      # Minimum N-Triples literal escape: backslash, double-quote,
      # LF, CR, TAB. The store round-trips these unchanged.
      def escape_literal(string)
        string
          .gsub("\\", "\\\\\\\\")
          .gsub('"', '\\"')
          .gsub("\n", '\\n')
          .gsub("\r", '\\r')
          .gsub("\t", '\\t')
      end
    end
  end
end
