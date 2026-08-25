# frozen_string_literal: true

require_relative "prose"
require_relative "canonical_id"

module Mmg
  module SemanticEditor
    # THE DEFAULT VIEW: AN EDIT SHOWN AS A DIFF.
    #
    # + and - mean one thing everywhere. On the board they are affordances --
    # add a card, remove a card. Here they are the record of the same acts,
    # already performed: a line that came into being, a line that went away.
    # A person who has understood the buttons has already understood the diff.
    #
    # Showing edits this way is not decoration. The alternative -- rendering the
    # new text and trusting the reader to notice what moved -- hides exactly the
    # thing that matters when one paragraph is about to land as several
    # simultaneous writes. A diff makes the SCOPE of an edit legible before it
    # is applied, which is the whole reason the plan is offered whole or not at
    # all.
    #
    # The diff is over the PROSE the person actually edited, not over the record
    # fields underneath. They typed text; they should be shown text.
    module Diff
      module_function

      ADDED = "+"
      REMOVED = "-"
      CONTEXT = " "

      MARKERS = [ADDED, REMOVED, CONTEXT].freeze

      # before/after: either a frame Hash (as Prose.render takes) or prose text.
      def of(before:, after:)
        b = blocks(before)
        return b unless b[:ok]

        a = blocks(after)
        return a unless a[:ok]

        lines = []
        added = []
        removed = []
        changed = []

        order(b[:ids], a[:ids]).each do |cid|
          was = b[:blocks][cid]
          now = a[:blocks][cid]

          if was.nil?
            added << cid
            lines.concat(mark(ADDED, now))
          elsif now.nil?
            removed << cid
            lines.concat(mark(REMOVED, was))
          elsif same?(was, now)
            lines.concat(mark(CONTEXT, now))
          else
            changed << cid
            lines.concat(within(was, now))
          end
        end

        { ok: true,
          text: "#{lines.join("\n")}\n",
          lines: lines,
          added: added,
          removed: removed,
          changed: changed,
          touched: added + removed + changed,
          clean: added.empty? && removed.empty? && changed.empty? }
      end

      # A one-line account of the edit, for a surface with no room for the diff.
      def summary(d)
        return d unless d.is_a?(Hash) && d[:ok]
        return { ok: true, text: "No change." } if d[:clean]

        parts = []
        parts << "#{d[:added].length} added" unless d[:added].empty?
        parts << "#{d[:changed].length} changed" unless d[:changed].empty?
        parts << "#{d[:removed].length} removed" unless d[:removed].empty?
        { ok: true, text: "#{parts.join(', ')}." }
      end

      # Which underlying structures this edit would reach. The diff shows what
      # the text says; this shows where it lands.
      def targets(d)
        return d unless d.is_a?(Hash) && d[:ok]

        found = d[:touched].filter_map do |cid|
          t = CanonicalId.target(cid)
          t[:ok] ? t[:target] : nil
        end
        { ok: true, targets: found.uniq.sort }
      end

      # Deletions keep their original position rather than being swept to the
      # end -- a removed clarification should appear under the meaning it was
      # removed from, which is the only place it means anything.
      def order(before_ids, after_ids)
        out = []
        i = 0
        after_ids.each do |id|
          while i < before_ids.length && before_ids[i] != id
            out << before_ids[i] unless after_ids.include?(before_ids[i])
            i += 1
          end
          out << id
          i += 1 if i < before_ids.length && before_ids[i] == id
        end
        while i < before_ids.length
          out << before_ids[i] unless after_ids.include?(before_ids[i])
          i += 1
        end
        out.uniq
      end

      def mark(marker, block)
        return [] if block.nil?

        pad = pad_for(block)
        [line(marker, pad, block[:label])] +
          body_lines(block).map { |l| line(marker, pad, l) }
      end
      private_class_method :mark

      # A changed block is diffed line by line, not replaced wholesale. Marking
      # an untouched heading as removed-then-added is noise, and noise in a
      # diff is worse than in prose: it trains the reader to skim the one view
      # whose entire job is to be read closely.
      def within(was, now)
        pad = pad_for(now)
        out = []

        if was[:label] == now[:label]
          out << line(CONTEXT, pad, now[:label])
        else
          out << line(REMOVED, pad, was[:label])
          out << line(ADDED, pad, now[:label])
        end

        old_body = body_lines(was)
        new_body = body_lines(now)
        if old_body == new_body
          out.concat(new_body.map { |l| line(CONTEXT, pad, l) })
        else
          out.concat(old_body.map { |l| line(REMOVED, pad, l) })
          out.concat(new_body.map { |l| line(ADDED, pad, l) })
        end

        out
      end
      private_class_method :within

      def line(marker, pad, text) = "#{marker}#{pad}#{text}".rstrip
      private_class_method :line

      def pad_for(block) = Prose::INDENT.fetch(block[:kind], "")
      private_class_method :pad_for

      def body_lines(block)
        block[:body].to_s.split("\n").map(&:strip).reject(&:empty?)
      end
      private_class_method :body_lines

      def same?(a, b)
        a[:label] == b[:label] && a[:body] == b[:body]
      end
      private_class_method :same?

      # The ids are what make this a diff of RECORDS rather than of characters.
      # Two blocks match because they are the same record, not because their
      # text happens to line up -- so rewording a meaning reads as one change,
      # not as a deletion next to an unrelated addition.
      def blocks(source)
        text = source.is_a?(String) ? source : Prose.render(source)[:text]
        return { ok: false, reason: :unrenderable, because: "could not render #{source.class} as prose" } if text.nil?

        parsed = Prose.parse(text)
        return parsed unless parsed[:ok]

        { ok: true,
          ids: parsed[:blocks].map { |x| x[:id] },
          blocks: parsed[:blocks].to_h { |x| [x[:id], x] } }
      end
      private_class_method :blocks
    end
  end
end
