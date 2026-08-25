# frozen_string_literal: true

require_relative "canonical_id"
require_relative "document"

module Mmg
  module SemanticEditor
    # ONE EDIT SESSION -> SEVERAL SIMULTANEOUS EDITS.
    #
    # A person editing a Frame in prose is, without thinking about it, editing a
    # frame record, three meaning records and five clarification records. This
    # module turns that one act into the set of writes it actually is, grouped
    # by the structure each write lands on.
    #
    # SIMULTANEOUS is the operative word. The set is offered whole or not at
    # all: a plan whose parts land separately can leave a Frame carrying a
    # Meaning that its Clarifications no longer explain, which is precisely the
    # incoherence the board exists to make visible. So a plan carries a
    # `coherent` flag and refuses to be applied piecemeal.
    module Decompose
      module_function

      # Also the order edits are applied in: nothing is removed before what
      # replaces it has landed.
      OPS = %i[create update delete].freeze

      # before/after are indexed documents (Document.index results) or ACIA
      # trees. Returns a plan: a list of edits grouped by target structure.
      def plan(before:, after:)
        b = indexed(before)
        return b unless b[:ok]

        a = indexed(after)
        return a unless a[:ok]

        edits = []
        refusals = []

        (a[:entries].keys - b[:entries].keys).each do |cid|
          edits << edit(:create, cid, a[:entries][cid], nil, refusals)
        end

        (b[:entries].keys - a[:entries].keys).each do |cid|
          edits << edit(:delete, cid, b[:entries][cid], nil, refusals)
        end

        (b[:entries].keys & a[:entries].keys).each do |cid|
          bp = b[:entries][cid][:props]
          ap = a[:entries][cid][:props]
          next if bp == ap

          edits << edit(:update, cid, a[:entries][cid], changed_keys(bp, ap), refusals)
        end

        edits.compact!
        edits.sort_by! { |e| [OPS.index(e[:op]), e[:canonical_id]] }
        checked = orphan_check(edits, a[:entries])

        { ok: true,
          edits: edits,
          by_target: edits.group_by { |e| e[:target] },
          refusals: refusals + checked,
          coherent: refusals.empty? && checked.empty?,
          count: edits.length }
      end

      # A plan is applied whole. `writer` receives (target, edits_for_target)
      # and returns an envelope; any refusal aborts before the first write.
      def apply(plan, &writer)
        return refuse(:no_plan, "expected a plan Hash") unless plan.is_a?(Hash) && plan[:edits]

        unless plan[:coherent]
          return refuse(:incoherent_plan,
                        "this plan would leave the document inconsistent: " \
                        "#{plan[:refusals].map { |r| r[:because] }.join('; ')}",
                        refusals: plan[:refusals])
        end

        return { ok: true, applied: 0, results: [] } if plan[:edits].empty?
        return refuse(:no_writer, "apply requires a block to perform the writes") unless writer

        results = []
        plan[:by_target].each do |target, edits|
          r = writer.call(target, edits)
          unless r.is_a?(Hash) && r[:ok]
            return refuse(:write_refused,
                          "writing #{target} was refused: #{r.is_a?(Hash) ? r[:because] : r.inspect}",
                          target: target, applied: results)
          end
          results << { target: target, count: edits.length, result: r }
        end

        { ok: true, applied: plan[:edits].length, results: results }
      end

      def edit(op, cid, entry, keys, refusals)
        t = CanonicalId.target(cid)
        unless t[:ok]
          refusals << { canonical_id: cid, op: op, reason: t[:reason], because: t[:because] }
          return nil
        end

        { op: op,
          canonical_id: cid,
          kind: t[:kind],
          target: t[:target],
          tier: entry[:tier],
          props: op == :delete ? nil : entry[:props],
          changed: keys }
      end
      private_class_method :edit

      # A delete that strands its children is the classic disclosure-tier
      # accident: the person was editing the immediate tier and never saw the
      # clarifications hanging off the meaning they removed.
      def orphan_check(edits, entries)
        deletes = edits.select { |e| e[:op] == :delete }.map { |e| e[:canonical_id] }
        return [] if deletes.empty?

        deletes.filter_map do |cid|
          survivors = entries.keys.select { |k| k.start_with?("#{cid}:") }
          next if survivors.empty?

          { canonical_id: cid, op: :delete, reason: :would_orphan,
            because: "deleting #{cid} would strand #{survivors.join(', ')}, which may be held at a " \
                     "deeper disclosure tier than the one being edited" }
        end
      end
      private_class_method :orphan_check

      def changed_keys(before, after)
        (before.keys | after.keys).select { |k| before[k] != after[k] }
      end
      private_class_method :changed_keys

      def indexed(doc)
        return doc if doc.is_a?(Hash) && doc[:entries].is_a?(Hash)

        Document.index(doc)
      end
      private_class_method :indexed

      def refuse(reason, because, **rest) = { ok: false, reason: reason, because: because }.merge(rest)
      private_class_method :refuse
    end
  end
end
