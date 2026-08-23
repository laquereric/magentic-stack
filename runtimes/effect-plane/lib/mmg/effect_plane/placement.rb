# frozen_string_literal: true
module Mmg
  module EffectPlane
    # Where did this effect actually land?
    #
    # This module NEVER infers a stage from a path string. A caller supplies
    # topology evidence and a mount inventory; if those do not establish a
    # single stage, it refuses. That refusal is the specific protection against
    # reading a successful container restart as a transaction rollback.
    module Placement
      module_function

      # topology_evidence:
      #   { stage:, image_paths: [], source_ref:, digest:, release_verified: }
      # mount_inventory:
      #   [ { path:, writable:, disposition: } ]  disposition nil == UNRESOLVED
      def declare(effect_id:, target:, topology_evidence:, mount_inventory:)
        ev     = topology_evidence.is_a?(Hash) ? topology_evidence : {}
        mounts = Array(mount_inventory)
        tgt    = target.to_s

        return refuse(:no_target, "a placement needs a target") if tgt.empty?

        claimed = ev[:stage]
        return refuse(:stage_not_evidenced,
                      "topology evidence declares no stage for #{tgt}; placement is never inferred from a path") if claimed.nil?

        known = Vocabulary.stage(claimed)
        return known unless known[:ok]

        covering    = mounts.select { |m| m[:writable] && covers?(m[:path], tgt) }
        unresolved  = covering.reject { |m| Vocabulary::MOUNT_DISPOSITIONS.include?(m[:disposition]) }
        image_bound = Array(ev[:image_paths]).any? { |p| covers?(p, tgt) }

        # A target claimed as image-resident while an unresolved writable mount
        # covers it is genuinely ambiguous: an image fork would appear to roll it
        # back while the mount silently survives.
        if image_bound && unresolved.any?
          return refuse(:ambiguous_mount,
                        "target is covered by both an image path declaration and an unresolved writable mount " \
                        "(#{unresolved.map { |m| m[:path] }.join(', ')})")
        end

        if unresolved.any? && known[:stage] != :host_volume
          return refuse(:unresolved_writable_volume,
                        "an unresolved writable mount covers #{tgt}; declare it excluded, immutable_input, " \
                        "or branch_seeded before claiming stage #{known[:stage]}")
        end

        missing = missing_evidence(known[:stage], ev, covering)
        return missing if missing

        { ok: true, effect_id: effect_id,
          placement: { stage: known[:stage], target: tgt, rollback: known[:rollback],
                       mutable: known[:mutable], content_address: known[:content_address],
                       survival: known[:survival],
                       evidence: { image_bound: image_bound, covering_mounts: covering.map { |m| m[:path] },
                                   digest: ev[:digest], source_ref: ev[:source_ref],
                                   release_verified: !!ev[:release_verified] } } }
      end

      # Per-stage evidence a claim must carry to be believed.
      def missing_evidence(stage, ev, covering)
        case stage
        when :source
          return refuse(:source_ref_missing, "a :source placement requires a source_ref (git SHA)") if blank?(ev[:source_ref])
        when :oci_image
          return refuse(:digest_missing, "an :oci_image placement requires a digest") if blank?(ev[:digest])
          unless ev[:release_verified]
            return refuse(:release_evidence_missing,
                          "an :oci_image placement requires verified release evidence; a digest alone does not " \
                          "certify provenance or admission")
          end
        when :snapshot_image
          return refuse(:digest_missing, "a :snapshot_image placement requires a digest") if blank?(ev[:digest])
        when :host_volume
          if covering.empty?
            return refuse(:volume_not_in_inventory,
                          "a :host_volume placement requires a writable mount in the inventory that covers the target")
          end
        end
        nil
      end

      def covers?(prefix, target)
        p = prefix.to_s.chomp("/")
        return false if p.empty?

        target == p || target.start_with?("#{p}/")
      end

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
