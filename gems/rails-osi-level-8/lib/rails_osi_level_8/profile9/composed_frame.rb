# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # PROSE IN, FRAME OUT.
    #
    # Stage 6 stored what a person typed and nothing read it back, so + Frame
    # wrote a receipt and the board still showed Y1-Y3. This is the seam that was
    # missing: a pure function from the bytes in the store to the frame the board
    # renders. Nothing here touches a store -- the caller supplies the prose and
    # says which id is free -- because the baseline must not know where its
    # consumer keeps things.
    #
    # The parse is DELIBERATELY small. Guessing structure out of free text is how
    # a reader ends up arguing with a machine about what they wrote, so there are
    # two rules, both stated on the surface that collects the text:
    #
    #   1. The first line names the frame. "Y4 — Title" supplies its own
    #      canonical id; anything else gets the next free one.
    #   2. Everything after it is the body.
    #
    # A single run-on paragraph is the one shape that gets help, because it is
    # what people actually type: the first sentence becomes the heading and the
    # rest becomes the body. Without that a 350-character paragraph renders as a
    # 350-character card title.
    module ComposedFrame
      module_function

      # Long enough for a real frame name, short enough that a run-on paragraph
      # is recognisably not one.
      HEADING_LIMIT = 80

      # "Y4 — Tidal access", "Y4 - Tidal access", "Y4: Tidal access".
      HEADING_WITH_ID = /\A([A-Z][0-9]+)\s*(?:—|–|--|-|:)\s*(.+)\z/

      def parse(prose, fallback_id:)
        text = prose.to_s.strip
        return refuse(:empty_prose, "there is nothing to make a frame out of") if text.empty?

        head, body = split_heading(text)
        return refuse(:empty_prose, "the frame has no heading") if head.empty?

        if (m = HEADING_WITH_ID.match(head))
          canonical_id = m[1]
          title        = m[2].strip
        else
          canonical_id = fallback_id.to_s
          title        = head
        end

        return refuse(:heading_missing, "a frame needs a name, not only an id") if title.empty?

        { ok: true,
          frame: { "canonicalId" => canonical_id,
                   "title" => title,
                   "label" => "#{canonical_id} — #{title}",
                   "body" => body.to_s.strip } }
      end

      # A blank line ends the heading. Failing that, so does the first sentence --
      # but ONLY once the line has run past what a heading plausibly is, so that
      # "Y4 — Tide, wind, and berth." stays whole.
      def split_heading(text)
        head, body = text.split(/\n\s*\n/, 2)
        head = head.to_s.tr("\n", " ").squeeze(" ").strip
        return [head, body] if head.length <= HEADING_LIMIT

        cut = head.index(/(?<=[.!?])\s/)
        return [head, body] unless cut

        [head[0...cut].strip, [head[(cut + 1)..].to_s.strip, body].compact.reject(&:empty?).join("\n\n")]
      end
      private_class_method :split_heading

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
