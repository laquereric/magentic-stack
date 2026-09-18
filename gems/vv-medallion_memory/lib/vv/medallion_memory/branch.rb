# frozen_string_literal: true

require_relative "store"
require_relative "refusal"
require_relative "fact"
require_relative "derivation"

module Vv
  module MedallionMemory
    # Branch-and-merge (Primitive 1, the last of the four).
    #
    # An agent never writes to canonical Silver/Gold: agent writes land on
    # a branch (Fact with branch_id), and canonical is adopted at merge.
    # Reads default to merged rows; a branch read sees main plus its own,
    # never another branch's.
    #
    # Merge policy is data (POLICY below), enforced by policy_reasons, not
    # a comment reviewers skim:
    #   new fact, subject unreferenced elsewhere -> auto-merge
    #   clean supersede/correct (base unmoved)  -> auto-merge
    #   contradiction / retraction / sensitive subject / hot writer -> review
    #
    # Merge is rebase-on-merge: the successor's belief starts at the merge
    # tx and the base closes there, so no two rows claim one belief
    # interval. Merge marks subjects merged and then embeds them --
    # embed-before-merge is unmerged_embed, which is why a rejected branch
    # leaves no embedding behind. Reject closes the branch rows' belief
    # (no live fact on that branch at current tx); history stays replayable.
    BranchRow = Struct.new(
      :branch_id, :parent_branch, :agent_id, :task_id,
      :created_at_tx, :status, :merged_at_tx, :abandoned_at_tx,
      keyword_init: true
    )

    ProposalRow = Struct.new(
      :proposal_id, :branch_id, :op, :subject_iri, :predicate, :object_value,
      :valid_from, :valid_to, :evidence_ref, :confidence,
      :fact_id, :base_fact_id, :base_valid_to, :base_tx_to, :status,
      keyword_init: true
    )

    MergeRow = Struct.new(
      :merge_id, :branch_id, :reviewer, :decision, :decided_at_tx,
      :rationale, :conflicts_resolved,
      keyword_init: true
    )

    module Branch
      OPS = %w[append supersede correct retract].freeze

      # Blast radius, as data. policy_reasons enforces every row.
      POLICY = [
        { change: "new fact, subject unreferenced elsewhere", gate: "auto-merge on schema + policy pass" },
        { change: "update that supersedes cleanly", gate: "auto-merge" },
        { change: "contradiction", gate: "review" },
        { change: "deletion / retraction", gate: "always review" },
        { change: "high-sensitivity subject", gate: "always review" },
        { change: "writer rejection-rate above threshold", gate: "always review" }
      ].freeze

      REJECTION_RATE_THRESHOLD = 0.5
      REJECTION_MIN_DECISIONS = 2

      module_function

      def open(store:, agent_id:, task_id:, parent_branch: nil)
        if agent_id.to_s.empty?
          return Refusal.build(Refusal::AUDIT_REJECTED, "agent_id is required: a branch nobody owns is a leak")
        end

        admission = store.admit(operation_id: "branch-open:#{store.current_position + 1}")
        row = BranchRow.new(
          branch_id: store.next_branch_id, parent_branch: parent_branch,
          agent_id: agent_id.to_s, task_id: task_id,
          created_at_tx: admission[:journal_position], status: "open"
        )
        store.branches << row
        Refusal.ok(branch_id: row.branch_id, agent_id: row.agent_id)
      end

      def find(store:, branch_id:)
        store.branches.find { |b| b.branch_id == branch_id.to_s }
      end

      def pending(store:, branch_id:)
        store.proposals.select { |p| p.branch_id == branch_id.to_s && p.status == "pending" }
      end

      def propose(store:, branch_id:, op:, subject_iri: nil, predicate: nil, object: nil,
                  valid_from: nil, valid_to: nil, evidence_ref: nil, confidence: nil,
                  base_fact_id: nil)
        branch = find(store: store, branch_id: branch_id)
        if branch.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "propose on unknown branch #{branch_id.inspect}")
        end
        unless branch.status == "open"
          return Refusal.build(Refusal::AUDIT_REJECTED, "propose on branch #{branch_id} which is #{branch.status}")
        end
        unless OPS.include?(op.to_s)
          return Refusal.build(Refusal::AUDIT_REJECTED, "proposal op must be #{OPS.join('|')}, got #{op.inspect}")
        end

        case op.to_s
        when "append"
          propose_append(store: store, branch: branch, subject_iri: subject_iri,
                         predicate: predicate, object: object, valid_from: valid_from,
                         valid_to: valid_to, evidence_ref: evidence_ref, confidence: confidence)
        when "supersede", "correct"
          propose_update(store: store, branch: branch, op: op.to_s, base_fact_id: base_fact_id,
                         object: object, valid_from: valid_from, evidence_ref: evidence_ref,
                         confidence: confidence)
        when "retract"
          propose_retract(store: store, branch: branch, base_fact_id: base_fact_id)
        end
      end

      def propose_append(store:, branch:, subject_iri:, predicate:, object:,
                         valid_from:, valid_to:, evidence_ref:, confidence:)
        r = Fact.append(
          store: store, subject_iri: subject_iri, predicate: predicate, object: object,
          valid_from: valid_from, evidence_ref: evidence_ref, branch_id: branch.branch_id,
          confidence: confidence
        )
        return r unless r[:ok]

        # valid_to on a proposal is carried on the row when set.
        row = Fact.find(store: store, fact_id: r[:fact][:fact_id])
        row.valid_to = valid_to unless valid_to.nil?
        record_proposal(store: store, branch: branch, op: "append", fact: row,
                        valid_to: row.valid_to, evidence_ref: evidence_ref, confidence: row.confidence)
      end
      private_class_method :propose_append

      def propose_update(store:, branch:, op:, base_fact_id:, object:, valid_from:,
                         evidence_ref:, confidence:)
        base = Fact.find(store: store, fact_id: base_fact_id)
        if base.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "proposal #{op} targets no fact #{base_fact_id.inspect}")
        end
        unless base.tx_to.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "proposal #{op} targets belief-closed fact #{base.fact_id}")
        end

        r = if op == "supersede"
              if valid_from.nil?
                return Refusal.build(Refusal::AUDIT_REJECTED, "proposal supersede needs valid_from: the world changed when?")
              end
              Fact.supersede(store: store, fact_id: base.fact_id, object: object,
                             valid_from: valid_from, evidence_ref: evidence_ref,
                             branch_id: branch.branch_id, confidence: confidence)
            else
              Fact.correct(store: store, fact_id: base.fact_id, object: object,
                           evidence_ref: evidence_ref,
                           branch_id: branch.branch_id, confidence: confidence)
            end
        return r unless r[:ok]

        row = Fact.find(store: store, fact_id: r[:fact][:fact_id])
        record_proposal(store: store, branch: branch, op: op, fact: row,
                        base_fact_id: base.fact_id, base_valid_to: base.valid_to, base_tx_to: base.tx_to,
                        valid_to: row.valid_to, evidence_ref: evidence_ref, confidence: row.confidence)
      end
      private_class_method :propose_update

      def propose_retract(store:, branch:, base_fact_id:)
        base = Fact.find(store: store, fact_id: base_fact_id)
        if base.nil? || !base.tx_to.nil? || !base.branch_id.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "retract needs a live canonical fact, got #{base_fact_id.inspect}")
        end

        store.admit(operation_id: "branch-retract:#{branch.branch_id}")
        record_proposal(store: store, branch: branch, op: "retract", fact: nil,
                        subject_iri: base.subject_iri, predicate: base.predicate,
                        object_value: base.object_value, valid_from: base.valid_from,
                        valid_to: base.valid_to, base_fact_id: base.fact_id,
                        base_valid_to: base.valid_to, base_tx_to: base.tx_to)
      end
      private_class_method :propose_retract

      def record_proposal(store:, branch:, op:, fact:, base_fact_id: nil,
                          base_valid_to: nil, base_tx_to: nil, subject_iri: nil,
                          predicate: nil, object_value: nil, valid_from: nil,
                          valid_to: nil, evidence_ref: nil, confidence: nil)
        prop = ProposalRow.new(
          proposal_id: store.next_proposal_id, branch_id: branch.branch_id, op: op,
          subject_iri: fact&.subject_iri || subject_iri,
          predicate: fact&.predicate || predicate,
          object_value: fact&.object_value.nil? ? object_value : fact.object_value,
          valid_from: fact&.valid_from || valid_from, valid_to: valid_to,
          evidence_ref: evidence_ref, confidence: fact&.confidence || confidence,
          fact_id: fact&.fact_id, base_fact_id: base_fact_id,
          base_valid_to: base_valid_to, base_tx_to: base_tx_to, status: "pending"
        )
        store.proposals << prop
        Refusal.ok(proposal_id: prop.proposal_id, branch_id: branch.branch_id, op: op,
                   fact_id: prop.fact_id)
      end
      private_class_method :record_proposal

      # Merge policy, enforced. Returns reason strings; empty means clean.
      def policy_reasons(store:, branch:)
        reasons = []
        proposals = pending(store: store, branch_id: branch.branch_id)

        if store.decisions(branch.agent_id) >= REJECTION_MIN_DECISIONS &&
           store.rejection_rate(branch.agent_id) > REJECTION_RATE_THRESHOLD
          reasons << "writer_rejection_rate_above_threshold"
        end

        canonical_live = store.facts.select { |f| f.branch_id.nil? && f.tx_to.nil? }
        proposals.each do |p|
          if store.sensitive_subjects.map(&:to_s).include?(p.subject_iri.to_s)
            reasons << "high_sensitivity_subject:#{p.subject_iri}"
          end
          case p.op
          when "retract"
            reasons << "deletion_always_reviewed:#{p.base_fact_id}"
          when "append"
            clashes = canonical_live.select do |f|
              f.subject_iri == p.subject_iri && f.predicate == p.predicate &&
                f.object_value.to_s != p.object_value.to_s &&
                intervals_overlap?(f.valid_from, f.valid_to, p.valid_from, p.valid_to)
            end
            reasons << "contradiction:#{p.subject_iri}" unless clashes.empty?
          when "supersede", "correct"
            base = Fact.find(store: store, fact_id: p.base_fact_id)
            if base.nil? || !base.tx_to.nil? || base.valid_to != p.base_valid_to
              reasons << "base_moved:#{p.base_fact_id}"
            elsif !base.branch_id.nil? && base.branch_id != branch.branch_id
              reasons << "cross_branch_base:#{p.base_fact_id}"
            end
          end
        end
        reasons.uniq
      end

      def intervals_overlap?(a_from, a_to, b_from, b_to)
        (a_from.nil? || b_to.nil? || a_from < b_to) &&
          (b_from.nil? || a_to.nil? || b_from < a_to)
      end
      private_class_method :intervals_overlap?

      def merge(store:, branch_id:, reviewer: nil, decision: nil, rationale: nil, vector: nil)
        branch = find(store: store, branch_id: branch_id)
        if branch.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "merge on unknown branch #{branch_id.inspect}")
        end
        unless branch.status == "open"
          return Refusal.build(Refusal::AUDIT_REJECTED, "merge on branch #{branch_id} which is #{branch.status}")
        end

        proposals = pending(store: store, branch_id: branch.branch_id)
        if proposals.empty?
          return Refusal.build(Refusal::AUDIT_REJECTED, "merge on branch #{branch_id} with no pending proposals")
        end

        decision = decision.nil? ? "auto" : decision.to_s
        unless %w[auto approve reject].include?(decision)
          return Refusal.build(Refusal::AUDIT_REJECTED, "merge decision must be auto|approve|reject, got #{decision.inspect}")
        end
        if decision == "reject" && reviewer.to_s.empty?
          return Refusal.build(Refusal::AUDIT_REJECTED, "a rejection names its reviewer: anonymous rejections poison the poisoning detector")
        end

        return reject_branch(store: store, branch: branch, reviewer: reviewer, rationale: rationale) if decision == "reject"

        reasons = policy_reasons(store: store, branch: branch)
        if !reasons.empty? && (decision != "approve" || reviewer.to_s.empty?)
          return Refusal.ok(decision: "review_required", branch_id: branch.branch_id, reasons: reasons)
        end
        if decision == "approve" && reviewer.to_s.empty?
          return Refusal.build(Refusal::AUDIT_REJECTED, "an approval names its reviewer")
        end

        perform_merge(store: store, branch: branch, proposals: proposals,
                      reviewer: reviewer, auto: decision == "auto",
                      overridden: decision == "approve" ? reasons : [], rationale: rationale,
                      vector: vector)
      end

      def perform_merge(store:, branch:, proposals:, reviewer:, auto:, overridden:,
                        rationale:, vector:)
        tx = store.admit(operation_id: "branch-merge:#{branch.branch_id}")[:journal_position]
        subjects = []
        proposals.each do |p|
          case p.op
          when "append"
            row = Fact.find(store: store, fact_id: p.fact_id)
            row.branch_id = nil
            subjects << row.subject_iri
          when "supersede", "correct"
            base = Fact.find(store: store, fact_id: p.base_fact_id)
            row = Fact.find(store: store, fact_id: p.fact_id)
            if p.op == "supersede"
              base.valid_to = row.valid_from
              Derivation.cascade(store: store, fact_id: base.fact_id, kind: :supersession)
            else
              Derivation.cascade(store: store, fact_id: base.fact_id, kind: :correction)
            end
            base.tx_to = tx
            row.tx_from = tx
            row.branch_id = nil
            subjects << row.subject_iri
          when "retract"
            base = Fact.find(store: store, fact_id: p.base_fact_id)
            base.tx_to = tx
            Derivation.cascade(store: store, fact_id: base.fact_id, kind: :forget)
            subjects << base.subject_iri
          end
          p.status = "merged"
        end

        subjects.uniq.each do |subject_iri|
          store.mark_merged(subject_iri)
          vector.embed(subject_iri, subject_text(store: store, subject_iri: subject_iri)) unless vector.nil?
        end

        branch.status = "merged"
        branch.merged_at_tx = tx
        record = MergeRow.new(
          merge_id: store.next_merge_id, branch_id: branch.branch_id, reviewer: reviewer,
          decision: auto ? "merged" : "approved", decided_at_tx: tx,
          rationale: rationale, conflicts_resolved: overridden
        )
        store.merge_records << record
        store.record_merge(branch.agent_id)
        Refusal.ok(decision: record.decision, branch_id: branch.branch_id,
                   merge_id: record.merge_id, subjects: subjects.uniq,
                   conflicts_resolved: overridden)
      end
      private_class_method :perform_merge

      def subject_text(store:, subject_iri:)
        store.facts.select { |f| f.subject_iri == subject_iri.to_s && f.branch_id.nil? }
             .map { |f| "#{f.predicate} #{f.object_value}" }.join(" ")
      end
      private_class_method :subject_text

      def reject_branch(store:, branch:, reviewer:, rationale:)
        tx = store.admit(operation_id: "branch-reject:#{branch.branch_id}")[:journal_position]
        close_branch_rows!(store: store, branch: branch, tx: tx)
        pending(store: store, branch_id: branch.branch_id).each { |p| p.status = "rejected" }
        branch.status = "rejected"
        record = MergeRow.new(
          merge_id: store.next_merge_id, branch_id: branch.branch_id, reviewer: reviewer,
          decision: "rejected", decided_at_tx: tx, rationale: rationale, conflicts_resolved: []
        )
        store.merge_records << record
        store.record_reject(branch.agent_id)
        Refusal.ok(decision: "rejected", branch_id: branch.branch_id, merge_id: record.merge_id)
      end
      private_class_method :reject_branch

      def abandon(store:, branch_id:)
        branch = find(store: store, branch_id: branch_id)
        if branch.nil?
          return Refusal.build(Refusal::AUDIT_REJECTED, "abandon on unknown branch #{branch_id.inspect}")
        end
        unless branch.status == "open"
          return Refusal.build(Refusal::AUDIT_REJECTED, "abandon on branch #{branch_id} which is #{branch.status}")
        end

        tx = store.admit(operation_id: "branch-abandon:#{branch.branch_id}")[:journal_position]
        close_branch_rows!(store: store, branch: branch, tx: tx)
        pending(store: store, branch_id: branch.branch_id).each { |p| p.status = "abandoned" }
        branch.status = "abandoned"
        branch.abandoned_at_tx = tx
        Refusal.ok(branch_id: branch.branch_id, status: "abandoned")
      end

      # No residue: every live row on the branch closes its belief here.
      # History stays replayable (tx_to set, not deleted); current reads
      # exclude closed rows, so the branch vanishes from the present.
      def close_branch_rows!(store:, branch:, tx:)
        store.facts.each do |f|
          f.tx_to = tx if f.branch_id == branch.branch_id && f.tx_to.nil?
        end
      end
      private_class_method :close_branch_rows!

      def reap(store:, older_than:)        unless older_than.is_a?(Integer) && older_than >= 0
          return Refusal.build(Refusal::AUDIT_REJECTED, "reap needs older_than as journal positions, got #{older_than.inspect}")
        end

        now = store.current_position
        old = store.branches.select do |b|
          b.status == "abandoned" && !b.abandoned_at_tx.nil? && (now - b.abandoned_at_tx) >= older_than
        end
        old_ids = old.map(&:branch_id)
        store.branches.reject! { |b| old_ids.include?(b.branch_id) }
        store.proposals.reject! { |p| old_ids.include?(p.branch_id) }
        Refusal.ok(reaped: old_ids)
      end
    end
  end
end
