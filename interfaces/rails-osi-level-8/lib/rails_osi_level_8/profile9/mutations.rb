# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # P9.4 — token/ACIA successors + InteractionEvent. Append-only in Graph.
    # Fail-closed: a refused gate never activates a successor.
    module Mutations
      TOKEN_SET_KEYS = %w[predecessorCid predecessorDigest tokenDelta successor approvalEvidenceCid].freeze
      ACIA_MUTATE_KEYS = %w[predecessorCid predecessorDigest successor tokenSetCid pageCid].freeze
      INTERACTION_KEYS = %w[
        eventKind receiptCid receipt aciaDocumentDigest tokenSetDigest
        shownContext collectedEffect component pageCid actorCid
        machineContextCid machineEffectCid authorizationEvidenceCid correlationId
      ].freeze
      EVENT_KINDS = %w[context_presented effect_collected effect_committed effect_refused].freeze
      DECISIONS = %w[permit deny approve refuse].freeze

      module_function

      def token_set(params)
        params = Request.closed!(params, TOKEN_SET_KEYS)
        pred_cid = Request.require_cid!(params, "predecessorCid")
        pred_digest = Request.require_cid!(params, "predecessorDigest")
        pred = Graph.token_set(pred_cid)
        Request.unresolved!("tokenSet", pred_cid) unless pred
        unless pred_cid == Graph.active_token_cid && pred["digest"] == pred_digest
          Request.unresolved!("tokenSet", pred_cid)
        end
        unless params["tokenDelta"] || params["successor"]
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => "tokenDelta|successor", "profile_id" => Vocabulary::PROFILE_ID }
          )
        end

        candidate = build_token_candidate(pred, params)
        lint = DesignGate.lint(candidate)
        Graph.put_evidence!(gate_record("ux.token.set", "design", lint.passed?, lint.to_h))
        unless lint.passed?
          raise KnownRefusal.new(
            lint.reason,
            { "profile_id" => Vocabulary::PROFILE_ID, "findings" => lint.findings, "activated" => false }
          )
        end

        digest = Request.digest(candidate["tokens"])
        cid = "cid:#{digest}"
        rec = {
          "cid" => cid,
          "@type" => "ux:DesignTokenSet",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "tokens" => candidate["tokens"],
          "digest" => digest,
          "predecessorCid" => pred_cid,
          "designMdProjection" => { "tokenSchemaVersion" => "ghis@1", "source" => "successor" }
        }
        Graph.put_token_set!(rec)
        Graph.activate_token!(cid)
        accepted_payload("ux.token.set", rec)
      end

      def acia_mutate_propose(params)
        params = Request.closed!(params, ACIA_MUTATE_KEYS)
        pred_cid = Request.require_cid!(params, "predecessorCid")
        pred_digest = Request.require_cid!(params, "predecessorDigest")
        successor = params["successor"]
        unless successor.is_a?(Hash)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => "successor", "profile_id" => Vocabulary::PROFILE_ID }
          )
        end

        pred = Graph.acia_doc(pred_cid)
        Request.unresolved!("acia", pred_cid) unless pred
        unless pred_cid == Graph.active_acia_cid && pred["digest"] == pred_digest
          Request.unresolved!("acia", pred_cid)
        end

        validation = Acia.validate(successor)
        Graph.put_evidence!(gate_record("ux.acia.mutate.propose", "acia", validation.conforms?, validation.to_h))
        unless validation.conforms?
          raise KnownRefusal.new(
            validation.reason || Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            (validation.because || {}).merge("activated" => false, "profile_id" => Vocabulary::PROFILE_ID)
          )
        end

        token_cid = params["tokenSetCid"].to_s
        token_cid = Graph.active_token_cid if token_cid.empty?
        token_rec = Graph.token_set(token_cid)
        Request.unresolved!("tokenSet", token_cid) unless token_rec

        unresolved = collect_unresolved_set_refs(successor, token_rec)
        Graph.put_evidence!(gate_record("ux.acia.mutate.propose", "token", unresolved.empty?, { "unresolved" => unresolved }))
        if unresolved.any?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:token_ref_broken],
            { "unresolvedTokens" => unresolved, "activated" => false, "profile_id" => Vocabulary::PROFILE_ID }
          )
        end

        cid = "cid:acia:#{validation.digest.delete_prefix('sha256:')}"
        rec = {
          "cid" => cid,
          "@type" => "ux:AciaDocument",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "document" => Request.stringify(successor),
          "digest" => validation.digest,
          "predecessorCid" => pred_cid,
          "tokenSetCid" => token_cid
        }
        Graph.put_acia!(rec)
        Graph.activate_acia!(cid)
        accepted_payload("ux.acia.mutate.propose", rec)
      end

      def interaction_record(params)
        params = Request.closed!(params, INTERACTION_KEYS)
        event_kind = Request.require_cid!(params, "eventKind")
        unless EVENT_KINDS.include?(event_kind)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "eventKind" => event_kind, "allowed" => EVENT_KINDS }
          )
        end

        receipt = resolve_receipt!(params)
        acia_digest = Request.require_cid!(params, "aciaDocumentDigest")
        token_digest = Request.require_cid!(params, "tokenSetDigest")
        if acia_digest != receipt["aciaDigest"] || token_digest != receipt["tokenDigest"]
          Request.unresolved!("receipt", receipt["cid"])
        end
        if event_kind == "context_presented" && receipt["ok"] == false
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:evidence_incomplete],
            { "message" => "render receipt is not ok", "receiptCid" => receipt["cid"] }
          )
        end

        receipt_cid = receipt["cid"].to_s
        if Graph.interaction_for(receipt_cid, event_kind)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "replay" => true, "receiptCid" => receipt_cid, "eventKind" => event_kind }
          )
        end

        collected = params["collectedEffect"]
        machine_effect_cid = nil
        if %w[effect_collected effect_committed].include?(event_kind)
          machine_effect_cid = commit_effect!(params, collected, event_kind)
        end

        rec = {
          "cid" => "cid:interaction:#{Request.digest({ "receipt" => receipt_cid, "eventKind" => event_kind, "at" => Graph.next_seq }).delete_prefix('sha256:')[0, 24]}",
          "@type" => "ux:InteractionEvent",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "eventKind" => event_kind,
          "receiptCid" => receipt_cid,
          "aciaDocumentDigest" => acia_digest,
          "tokenSetDigest" => token_digest,
          "pageCid" => params["pageCid"].to_s.empty? ? Graph::PAGE_CID : params["pageCid"],
          "journeyCid" => Graph::JOURNEY_CID,
          "flowCid" => Graph::FLOW_CID,
          "actorCid" => params["actorCid"].to_s.empty? ? Graph::ACTOR_CID : params["actorCid"],
          "component" => params["component"],
          "shownContext" => params["shownContext"],
          "collectedEffect" => collected,
          "machineContextCid" => params["machineContextCid"],
          "machineEffectCid" => machine_effect_cid || params["machineEffectCid"],
          "authorizationEvidenceCid" => params["authorizationEvidenceCid"],
          "correlationId" => params["correlationId"] || receipt["correlationId"]
        }
        Graph.put_receipt!(receipt)
        Graph.put_interaction!(rec)
        rec.merge("ok" => true, "accepted" => true)
      end

      def build_token_candidate(pred, params)
        if params["successor"].is_a?(Hash)
          succ = Request.stringify(params["successor"])
          map = succ["tokens"] || succ
          return { "tokens" => map }
        end

        map = Request.stringify(pred["tokens"] || {})
        delta = Request.stringify(params["tokenDelta"] || {})
        delta.each do |set_ref, pairs|
          next unless pairs.is_a?(Hash)

          map[set_ref] ||= {}
          pairs.each { |k, v| map[set_ref][k.to_s] = v }
        end
        { "tokens" => map }
      end
      private_class_method :build_token_candidate

      def collect_unresolved_set_refs(doc, token_rec)
        unresolved = []
        walk = lambda do |node, path|
          return unless node.is_a?(Hash)

          set_ref = node.dig("slt", "tokenSignature", "setRef").to_s
          if !set_ref.empty? && !(token_rec["tokens"] || {}).key?(set_ref)
            unresolved << { "path" => path, "setRef" => set_ref }
          end
          Array(node["children"]).each_with_index { |child, i| walk.call(child, "#{path}.children[#{i}]") }
        end
        root = doc["root"] || doc["rootNode"]
        walk.call(root, "root")
        unresolved
      end
      private_class_method :collect_unresolved_set_refs

      def resolve_receipt!(params)
        receipt = params["receipt"]
        receipt = Graph.receipt(params["receiptCid"]) if receipt.nil? && Request.present?(params["receiptCid"])
        unless receipt.is_a?(Hash) && Request.present?(receipt["cid"])
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => "receipt", "profile_id" => Vocabulary::PROFILE_ID }
          )
        end
        Request.stringify(receipt)
      end
      private_class_method :resolve_receipt!

      def commit_effect!(params, collected, event_kind)
        unless collected.is_a?(Hash)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:effect_affordance_denied],
            { "missing" => "collectedEffect", "eventKind" => event_kind }
          )
        end

        page = Graph.page(params["pageCid"].to_s.empty? ? Graph::PAGE_CID : params["pageCid"])
        Request.unresolved!("page", params["pageCid"]) unless page

        contract_id = collected["effectContract"].to_s
        allowed = Array(page["effectContract"])
        decision = collected["decision"].to_s
        unless allowed.include?(contract_id) && DECISIONS.include?(decision)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:effect_affordance_denied],
            {
              "effectContract" => contract_id,
              "decision" => decision,
              "allowedContracts" => allowed,
              "profile_id" => Vocabulary::PROFILE_ID
            }
          )
        end
        return nil unless event_kind == "effect_committed"

        "cid:effect:#{Request.digest(collected).delete_prefix('sha256:')[0, 24]}"
      end
      private_class_method :commit_effect!

      def gate_record(operation, gate, passed, detail)
        {
          "cid" => "cid:gate:#{Request.digest({ operation: operation, gate: gate, n: Graph.next_seq }).delete_prefix('sha256:')[0, 16]}",
          "operation" => operation,
          "gate" => gate,
          "passed" => passed,
          "detail" => detail,
          "ledgerPlacement" => "canonical",
          "profileId" => Vocabulary::PROFILE_ID
        }
      end
      private_class_method :gate_record

      def accepted_payload(operation, rec)
        {
          "ok" => true,
          "accepted" => true,
          "operation" => operation,
          "cid" => rec["cid"],
          "digest" => rec["digest"],
          "predecessorCid" => rec["predecessorCid"],
          "activated" => true,
          "record" => rec
        }
      end
      private_class_method :accepted_payload
    end
  end
end
