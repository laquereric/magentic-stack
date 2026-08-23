# frozen_string_literal: true
module Mmg
  module EffectPlane
    # The C1-C9 contract, and the provenance ruling.
    #
    # "Transactional" here is deliberately scoped: a consistent selection of the
    # declared materialized stores plus branch activation. It does NOT mean
    # atomic rollback of arbitrary remote systems, volumes, or domain history.
    #
    # validate_contract is ALL-OR-NOTHING. It does not attempt best-effort
    # capture, and it reports every failed condition rather than the first.
    module Snapshot
      module_function

      def validate_contract(contract:)
        return refuse(:no_contract, "expected a contract Hash") unless contract.is_a?(Hash)

        failed = Vocabulary::CONDITION_IDS.filter_map do |id|
          result = send(:"check_#{id.to_s.downcase}", contract)
          next if result.nil?

          # A check may override the condition's default refusal: C2 in
          # particular must distinguish an unclassified store from one declared
          # the sole authority for domain facts.
          reason  = result.is_a?(Hash) ? result[:reason]  : Vocabulary::CONDITIONS[id][:refusal]
          because = result.is_a?(Hash) ? result[:because] : result
          { condition: id, reason: reason, because: because }
        end

        return { ok: true, satisfied: Vocabulary::CONDITION_IDS } if failed.empty?

        { ok: false, reason: failed.first[:reason], because: failed.first[:because],
          failed: failed, satisfied: Vocabulary::CONDITION_IDS - failed.map { |f| f[:condition] } }
      end

      # C1 -- every domain fact the capture represents is retained in the
      # authoritative append-only path, with an immutable cursor.
      def check_c1(c)
        a = c[:authority]
        return "no authority declaration; a snapshot may not abandon facts that exist only inside it" unless a.is_a?(Hash)
        return "authority is not declared retained" unless a[:retained]
        return "no immutable authority cursor supplied" if blank?(a[:cursor])

        nil
      end

      # C2 -- captured stores are a materialization, not the sole authority.
      def check_c2(c)
        stores = Array(c[:stores])
        return "no stores declared" if stores.empty?

        stores.each do |s|
          role = s[:role]
          return "store #{s[:name].inspect} declares no role" if role.nil?
          return "store #{s[:name].inspect} has unknown role #{role.inspect}" unless Vocabulary::STORE_ROLES.include?(role.to_sym)
          if role.to_sym == :authoritative
            return { reason: :sole_authority_store,
                     because: "store #{s[:name].inspect} is the sole authority for domain facts; forking it " \
                              "would discard Plane B truth, which must stay append-only" }
          end
          return "store #{s[:name].inspect} declares no reconstruction path" if blank?(s[:reconstruction])
        end
        nil
      end

      # C3 -- every writer stopped or fenced, every store capture certified.
      # A raw copy of a live SQLite WAL or a running graph store is NOT enough.
      def check_c3(c)
        b = c[:barrier]
        return "no quiescence barrier supplied" unless b.is_a?(Hash)
        return "barrier has no id" if blank?(b[:id])
        return "barrier does not report writers fenced" unless b[:fenced]

        writers = Array(b[:writers])
        acks    = Array(b[:acknowledgements])
        return "barrier declares no writers" if writers.empty?

        missing = writers - acks
        return "writers without acknowledgement: #{missing.join(', ')}" if missing.any?

        receipts = b[:receipts].is_a?(Hash) ? b[:receipts] : {}
        uncertified = Array(c[:stores]).map { |s| s[:name] }.reject { |n| receipts[n] }
        return "stores without a consistency-safe capture receipt: #{uncertified.join(', ')}" if uncertified.any?

        nil
      end

      # C4 -- no writable mount may silently remain attached.
      def check_c4(c)
        Array(c[:mounts]).each do |m|
          next unless m[:writable]
          unless Vocabulary::MOUNT_DISPOSITIONS.include?(m[:disposition])
            return "writable mount #{m[:path].inspect} has disposition #{m[:disposition].inspect}; " \
                   "declare it #{Vocabulary::MOUNT_DISPOSITIONS.join(', ')}"
          end
        end
        nil
      end

      # C5 -- the digest is bound to its ancestry and an attestation.
      def check_c5(c)
        adm = admissibility(c[:provenance])
        return adm[:because] unless adm[:ok]

        nil
      end

      # C6 -- secrets and private/operational bytes excluded.
      def check_c6(c)
        included = Array(c[:includes]).map { |v| v.to_s.to_sym }
        bad = included & Vocabulary::FORBIDDEN_CONTENT
        return "forbidden content in the snapshot payload: #{bad.join(', ')}" if bad.any?

        nil
      end

      # C7 -- effects outside the artifact are absent, fenced, or classified.
      def check_c7(c)
        unclosed = Array(c[:external_effects]).reject do |e|
          %i[absent idempotently_fenced compensable irreversible].include?(e[:closure])
        end
        return "external effects lack closure: #{unclosed.map { |e| e[:id] }.join(', ')}" if unclosed.any?

        nil
      end

      # C8 -- activation is recorded before/with the deployment selection.
      def check_c8(c)
        f = c[:fork]
        return "no fork record; an activation that is not appended did not happen" unless f.is_a?(Hash)
        return "fork record carries no activation event reference" if blank?(f[:activation_event_ref])

        nil
      end

      # C9 -- somebody owns keeping this reachable, and says for how long.
      def check_c9(c)
        r = c[:retention]
        return "no retention declaration" unless r.is_a?(Hash)
        return "retention has no owner" if blank?(r[:owner])
        return "retention has no class" if blank?(r[:retention_class])
        return "retention has neither expiry nor hold" if blank?(r[:expiry]) && !r[:hold]

        nil
      end

      # THE PROVENANCE RULING.
      #
      # Path A -- rebuild from captured input into a normal signed release.
      #   The production DEFAULT: it does not relax mmg-k3s admission or invent
      #   provenance after the fact.
      # Path B -- an attested EffectSnapshotPacket. An honestly-named NEW artifact
      #   class requiring a NEW verifier. NOT admitted by the current rule, and it
      #   must never masquerade as a Release Packet.
      # Anything else (a bare `docker commit` digest) -> :provenance_unbound.
      def admissibility(provenance)
        return refuse(:provenance_unbound, "no provenance supplied") unless provenance.is_a?(Hash)

        case provenance[:path]
        when :rebuilt_release
          unless provenance[:release_packet_verified] && provenance[:binds_to_digest]
            return refuse(:provenance_unbound,
                          "a rebuilt release must carry a verified Release Packet that BINDS to the OCI image")
          end
          { ok: true, path: :rebuilt_release, admissible: true,
            because: "a rebuilt, verified, digest-bound release satisfies the existing admission rule" }
        when :attested_packet
          return refuse(:provenance_unbound, "an attested packet requires an attestation") if blank?(provenance[:attestation])

          # Deliberately ok:true -- the packet is WELL-FORMED. It is simply not
          # admissible under the current control-plane contract, and saying so is
          # the honest answer rather than a refusal or a silent promotion.
          { ok: true, path: :attested_packet, admissible: false,
            requires: :control_plane_extension,
            because: "an EffectSnapshotPacket is a NEW artifact class; the stated admission rule accepts only " \
                     "a verified Release Packet, so this must not be presented as an admitted Revision" }
        else
          refuse(:provenance_unbound,
                 "a bare committed image has no verified Release Packet and no attestation; " \
                 "`docker commit` is not an admissible release path")
        end
      end

      # The declarative manifest. Runs no Docker, creates no image, signs
      # nothing, deploys nothing.
      def manifest(contract:, artifact:)
        valid = validate_contract(contract: contract)
        return { ok: false, reason: :contract_invalid, because: valid[:because], failed: valid[:failed] } unless valid[:ok]

        art    = artifact.is_a?(Hash) ? artifact : {}
        policy = contract[:policy].is_a?(Hash) ? contract[:policy] : {}

        if policy.key?(:snapshot_rate_approved) && !policy[:snapshot_rate_approved]
          return refuse(:snapshot_rate_unapproved,
                        "the declared snapshot cadence is not approved; declare bounded state size, retention " \
                        "owner, quiescence mechanism, and a layer-cost budget rather than assuming a cost")
        end

        { ok: true, manifest: {
          snapshot_id: art[:snapshot_id], snapshot_image_digest: art[:snapshot_image_digest],
          base_release_digest: art[:base_release_digest], base_image_digests: Array(art[:base_image_digests]),
          source_ref: art.key?(:source_ref) ? art[:source_ref] : :unknown,
          branch: contract.dig(:fork, :branch), parent_snapshot: contract.dig(:fork, :parent_snapshot),
          authority_cursor: contract.dig(:authority, :cursor),
          stores: Array(contract[:stores]), barrier: contract[:barrier], mounts: Array(contract[:mounts]),
          external_effects: Array(contract[:external_effects]), exclusions: Array(contract[:excludes]),
          layers: art[:layers], retention: contract[:retention], attestation: contract.dig(:provenance, :attestation)
        } }
      end

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
