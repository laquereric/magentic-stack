# frozen_string_literal: true
module Mmg
  module EffectPlane
    # The closed vocabulary. Nothing outside these frozen sets is a stage, a
    # classification, or a legitimacy condition -- an unknown value is refused,
    # never coerced into the nearest match.
    module Vocabulary
      module_function

      # The five pipeline stages:
      #   source -> oci_image -> container_layer -> snapshot_image -> host_volume
      #
      # The load-bearing asymmetry lives in the last row: re-instantiating a
      # prior digest rolls back everything in the IMAGE and nothing in a VOLUME.
      STAGES = {
        source: {
          mutable: true,  content_address: :git_sha, survival: :independent_of_container,
          rollback: :select_revision
        }.freeze,
        oci_image: {
          mutable: false, content_address: :oci_digest, survival: :survives_container_death,
          rollback: :reinstantiate_verified_image
        }.freeze,
        container_layer: {
          mutable: true,  content_address: nil, survival: :lost_on_container_death,
          rollback: :discard_and_recreate
        }.freeze,
        snapshot_image: {
          mutable: false, content_address: :oci_digest, survival: :survives_container_death_while_retained,
          rollback: :fork_and_activate
        }.freeze,
        host_volume: {
          mutable: true,  content_address: nil, survival: :survives_container_death,
          rollback: :not_by_image_selection
        }.freeze
      }.freeze

      CLASSIFICATIONS = %i[reversible fork_reversible compensable irreversible refused].freeze

      # C1-C9 are a CONJUNCTIVE contract. A capture that cannot prove even one
      # may be a useful engineering artifact, but it is not an effect-plane
      # snapshot and cannot be called a rollback point.
      CONDITIONS = {
        C1: { name: :authoritative_history_retention, refusal: :domain_truth_not_retained }.freeze,
        # C2 has TWO refusals: a store may be unclassified, or classified as the
        # sole authority for domain facts. They are different failures and a
        # caller must be able to tell them apart.
        C2: { name: :derived_state_declaration,       refusal: :unclassified_store_authority,
              also: %i[sole_authority_store].freeze }.freeze,
        C3: { name: :complete_quiescence_barrier,     refusal: :quiescence_unproven }.freeze,
        C4: { name: :explicit_volume_closure,         refusal: :unresolved_writable_volume }.freeze,
        C5: { name: :provenance_closure,              refusal: :provenance_unbound }.freeze,
        C6: { name: :secret_and_policy_exclusion,     refusal: :forbidden_snapshot_content }.freeze,
        C7: { name: :external_effect_closure,         refusal: :external_effect_unclosed }.freeze,
        C8: { name: :durable_branch_record,           refusal: :fork_not_recorded }.freeze,
        C9: { name: :retention_viability,             refusal: :retention_undefined }.freeze
      }.freeze

      CONDITION_IDS = CONDITIONS.keys.freeze

      # A writable mount must be explicitly disposed of before an image fork can
      # claim to have rolled anything back.
      MOUNT_DISPOSITIONS = %i[excluded immutable_input branch_seeded].freeze

      # Byte classes that must never enter a snapshot layer.
      FORBIDDEN_CONTENT = %i[secrets credentials private_homes user_uploads logs queues].freeze

      # How a store relates to domain truth.
      STORE_ROLES = %i[materialization projection index cache authoritative].freeze
      REPLAYABLE_ROLES = %i[materialization projection index cache].freeze

      def stage(value)
        s = value.to_s.to_sym
        rec = STAGES[s]
        return { ok: false, reason: :unknown_stage, because: "#{value.inspect} is not one of #{STAGES.keys.join(', ')}" } if rec.nil?

        { ok: true, stage: s }.merge(rec)
      end

      def classification(value)
        c = value.to_s.to_sym
        return { ok: true, classification: c } if CLASSIFICATIONS.include?(c)

        { ok: false, reason: :unknown_classification,
          because: "#{value.inspect} is not one of #{CLASSIFICATIONS.join(', ')}" }
      end

      def condition(id)
        rec = CONDITIONS[id.to_s.to_sym]
        return { ok: false, reason: :unknown_condition, because: "#{id.inspect} is not one of #{CONDITION_IDS.join(', ')}" } if rec.nil?

        { ok: true, id: id.to_s.to_sym }.merge(rec)
      end

      RULE = "Plane C records WHICH immutable materialization is active and how it was produced. " \
             "Selecting a prior materialization is a FORK, never a rewind of domain truth."
    end
  end
end
