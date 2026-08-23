# frozen_string_literal: true

require_relative "canonical_id"

module Mmg
  module SemanticEditor
    # PROSE MODE.
    #
    # A Frame is easier to think about as a paragraph than as a form. Prose mode
    # renders the Frame, its Meanings and their Clarifications as one editable
    # text, and reads that text back as structure.
    #
    # The round trip is only safe because each line carries its canonical id. A
    # person editing prose is editing several records at once and needs no
    # awareness of that; the ids are what let the editor put each line back
    # where it came from. A line whose id is removed is a new record, and a
    # record whose line disappears is a deletion -- both are decisions the
    # editor must surface, not guess at, which is why Prose only reports them
    # and Decompose is what acts.
    #
    # The format is deliberately plain. It is not markdown and it is not YAML;
    # it is the smallest thing that survives a person retyping it by hand.
    #
    #   [Y1] Harbour operations
    #   Frames what we are here to look after and what counts as looking after it.
    #
    #     [Y1:M1] Berth allocation is a duty of care
    #     A berth is not a slot on a chart. Who gets one, and when, decides whose
    #     livelihood is interrupted.
    #
    #       [Y1:M1:C1] A vessel already alongside is not thereby entitled to stay.
    #
    module Prose
      module_function

      HEADER = /\A\s*\[([A-Z0-9:]+)\]\s*(.*)\z/

      INDENT = { frame: "", meaning: "  ", clarification: "    " }.freeze

      # Structure -> text.
      #
      # frame: { id:, label:, body:, meanings: [ { id:, label:, body:,
      #          clarifications: [ { id:, label:, body: } ] } ] }
      def render(frame)
        return refuse(:no_frame, "expected a frame Hash") unless frame.is_a?(Hash)

        id = frame[:id] || frame["id"]
        parsed = CanonicalId.parse(id)
        return parsed unless parsed[:ok]
        return refuse(:not_a_frame, "#{id} is a #{parsed[:kind]}, not a frame") unless parsed[:kind] == :frame

        lines = block(frame, :frame)
        each(frame, :meanings).each do |m|
          lines << ""
          lines.concat(block(m, :meaning))
          each(m, :clarifications).each do |c|
            lines << ""
            lines.concat(block(c, :clarification))
          end
        end

        { ok: true, text: "#{lines.join("\n").rstrip}\n" }
      end

      # Text -> structure. Never raises, never guesses: a line it cannot place is
      # reported, not dropped.
      def parse(text)
        return refuse(:no_text, "expected prose text") unless text.is_a?(String)

        blocks = []
        problems = []
        current = nil

        text.lines.each_with_index do |raw, i|
          line = raw.rstrip

          if (m = line.match(HEADER))
            cid = m[1]
            p = CanonicalId.parse(cid)
            if p[:ok]
              current = { id: cid, kind: p[:kind], label: m[2].strip, body_lines: [], line: i + 1 }
              blocks << current
            else
              problems << { line: i + 1, reason: p[:reason], because: p[:because] }
              current = nil
            end
            next
          end

          next if line.strip.empty?

          if current.nil?
            problems << { line: i + 1, reason: :orphan_line,
                          because: "#{line.strip.inspect} precedes any [id] header, so it belongs to nothing" }
            next
          end

          current[:body_lines] << line.strip
        end

        frame = blocks.find { |b| b[:kind] == :frame }
        return refuse(:no_frame_block, "prose contains no [Yn] frame header") if frame.nil?

        extra = blocks.select { |b| b[:kind] == :frame } - [frame]
        unless extra.empty?
          problems << { line: extra.first[:line], reason: :multiple_frames,
                        because: "prose mode edits one frame at a time; found #{extra.map { |b| b[:id] }.join(', ')} as well" }
        end

        out_of_frame = blocks.reject { |b| CanonicalId.in_frame?(b[:id], frame[:id]) }
        unless out_of_frame.empty?
          problems << { line: out_of_frame.first[:line], reason: :cross_frame,
                        because: "#{out_of_frame.map { |b| b[:id] }.join(', ')} do not belong to #{frame[:id]}" }
        end

        { ok: true,
          frame: assemble(frame, blocks),
          blocks: blocks.map { |b| shape(b) },
          problems: problems }
      end

      # Did the text come back saying the same thing? Compares by canonical id,
      # so reordering is not a change but a removed id is.
      def diff(before, after)
        a = render(before)
        return a unless a[:ok]

        b = after.is_a?(String) ? parse(after) : parse(render(after)[:text].to_s)
        return b unless b[:ok]

        was = parse(a[:text])[:blocks].to_h { |x| [x[:id], x] }
        now = b[:blocks].to_h { |x| [x[:id], x] }

        changed = (was.keys & now.keys).reject do |id|
          was[id][:label] == now[id][:label] && was[id][:body] == now[id][:body]
        end

        { ok: true,
          added: now.keys - was.keys,
          removed: was.keys - now.keys,
          changed: changed,
          unchanged: (was.keys & now.keys) - changed }
      end

      def block(rec, kind)
        pad = INDENT.fetch(kind)
        id = rec[:id] || rec["id"]
        label = (rec[:label] || rec["label"]).to_s.strip
        body = (rec[:body] || rec["body"]).to_s.strip

        out = ["#{pad}[#{id}] #{label}".rstrip]
        body.split("\n").each { |l| out << "#{pad}#{l.strip}" } unless body.empty?
        out
      end
      private_class_method :block

      def each(rec, key)
        Array(rec[key] || rec[key.to_s])
      end
      private_class_method :each

      def shape(b)
        { id: b[:id], kind: b[:kind], label: b[:label], body: b[:body_lines].join(" ").strip, line: b[:line] }
      end
      private_class_method :shape

      def assemble(frame, blocks)
        meanings = blocks.select { |b| b[:kind] == :meaning }.map do |m|
          clar = blocks.select { |c| c[:kind] == :clarification && c[:id].start_with?("#{m[:id]}:") }
          shape(m).merge(clarifications: clar.map { |c| shape(c) })
        end
        shape(frame).merge(meanings: meanings)
      end
      private_class_method :assemble

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
