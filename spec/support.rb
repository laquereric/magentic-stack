# frozen_string_literal: true
# Fakes for topology evidence, barriers, append receipts, and resolvers.
# No Docker daemon is required inside the unit-test boundary.
module Fx
  DIGEST  = "sha256:#{'a' * 64}"
  DIGEST2 = "sha256:#{'b' * 64}"

  module_function

  def place(stage:, target: "/app/state.db", **ev)
    Mmg::EffectPlane::Placement.declare(
      effect_id: "e1", target: target,
      topology_evidence: { stage: stage }.merge(ev),
      mount_inventory: ev.delete(:mounts) || []
    )
  end

  # A contract satisfying all of C1-C9; specs break exactly one condition.
  def contract(**over)
    {
      authority: { retained: true, cursor: "urn:mm:res:cursor:8891" },
      stores: [{ name: "site", role: :materialization, reconstruction: "replay from RES",
                 capture_digest: DIGEST }],
      barrier: { id: "b-1", fenced: true, writers: %w[puma worker],
                 acknowledgements: %w[puma worker], receipts: { "site" => "rcpt-1" } },
      mounts: [{ path: "/data", writable: true, disposition: :excluded }],
      provenance: { path: :rebuilt_release, release_packet_verified: true, binds_to_digest: DIGEST,
                    attestation: "sig-1" },
      includes: %i[app_code materialized_state],
      excludes: %i[secrets private_homes],
      external_effects: [{ id: "stripe-charge", closure: :compensable }],
      fork: { activation_event_ref: "evt-1", branch: "branch:prod", parent_snapshot: DIGEST2 },
      retention: { owner: "platform", retention_class: :checkpoint, expiry: "P30D" }
    }.merge(over)
  end

  def event(**over)
    Mmg::EffectPlane::Fork.activation_event(
      **{ branch: "branch:prod", parent_snapshot: DIGEST2, selected_snapshot: DIGEST,
          reason: :operator_selected_recovery_point, authority_cursor: "urn:mm:res:cursor:8891",
          volume_disposition: :fresh_branch_seed }.merge(over)
    )
  end

  def reference(**over)
    { iri: "urn:mm:effect:result:42", snapshot_digest: DIGEST, branch: "branch:prod",
      locator: { path: "/snap/result.json" }, media_type: "application/json",
      schema_ref: "urn:mm:schema:result", retention: { owner: "platform" } }.merge(over)
  end
end
