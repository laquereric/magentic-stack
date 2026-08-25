# frozen_string_literal: true

module Mmg
  module SemanticEditor
    # THE ROUTING KEY.
    #
    # A canonical id says what a node IS and therefore which underlying
    # structure an edit to it belongs to. Without it, an edited document is a
    # blob that can only be written back wholesale; with it, one edit session
    # decomposes into several simultaneous, correctly-targeted edits.
    #
    #   X1            Input        frame-independent
    #   Y1            Frame        the apparatus
    #   Y1:M1         Meaning      belongs to the Frame
    #   Y1:M1:C1      Clarification
    #   X1:Y1         Translation  DERIVED -- never a write target
    #   X1:Y1:R1      Reference    produced, and settled
    #   X1:Y1:Z1      Stewardship  produced, and decided
    #
    # The two sides of the model are legible in the id itself: what belongs to
    # the Frame leads with the Frame; what is produced by applying it leads with
    # the Input it is about.
    module CanonicalId
      module_function

      INPUT = /\AX(\d+)\z/
      FRAME = /\AY(\d+)\z/
      MEANING = /\AY(\d+):M(\d+)\z/
      CLARIFICATION = /\AY(\d+):M(\d+):C(\d+)\z/
      TRANSLATION = /\AX(\d+):Y(\d+)\z/
      REFERENCE = /\AX(\d+):Y(\d+):R(\d+)\z/
      STEWARDSHIP = /\AX(\d+):Y(\d+):Z(\d+)\z/

      # kind => the structure an edit lands on.
      TARGETS = {
        input: :inputs,
        frame: :frames,
        meaning: :meanings,
        clarification: :clarifications,
        translation: nil, # derived; see DERIVED_KINDS
        reference: :references,
        stewardship: :stewardship_carries
      }.freeze

      # A Translation is derived per request and is never stored, so it is never
      # a write target. An edit addressed to one is a category error, not a
      # missing feature -- what the editor means is an edit to something the
      # Translation was derived FROM.
      DERIVED_KINDS = %i[translation].freeze

      def parse(id)
        s = id.to_s.strip
        return refuse(:blank_id, "a canonical id is required") if s.empty?

        if (m = s.match(CLARIFICATION))
          return ok(:clarification, s, frame: "Y#{m[1]}", meaning: "Y#{m[1]}:M#{m[2]}", ordinal: m[3].to_i)
        end
        if (m = s.match(REFERENCE))
          return ok(:reference, s, input: "X#{m[1]}", frame: "Y#{m[2]}", ordinal: m[3].to_i)
        end
        if (m = s.match(STEWARDSHIP))
          return ok(:stewardship, s, input: "X#{m[1]}", frame: "Y#{m[2]}", ordinal: m[3].to_i)
        end
        if (m = s.match(MEANING))
          return ok(:meaning, s, frame: "Y#{m[1]}", ordinal: m[2].to_i)
        end
        if (m = s.match(TRANSLATION))
          return ok(:translation, s, input: "X#{m[1]}", frame: "Y#{m[2]}")
        end
        if (m = s.match(FRAME))
          return ok(:frame, s, ordinal: m[1].to_i)
        end
        if (m = s.match(INPUT))
          return ok(:input, s, ordinal: m[1].to_i)
        end

        refuse(:unrecognized_id, "#{s.inspect} matches no canonical id shape")
      end

      def kind(id)
        p = parse(id)
        p[:ok] ? { ok: true, kind: p[:kind] } : p
      end

      # Which underlying structure does an edit to this id belong to?
      def target(id)
        p = parse(id)
        return p unless p[:ok]

        if DERIVED_KINDS.include?(p[:kind])
          return refuse(:derived_not_writable,
                        "#{p[:id]} is a Translation, which is derived per request and never stored; " \
                        "edit what it was derived from instead")
        end

        { ok: true, id: p[:id], kind: p[:kind], target: TARGETS.fetch(p[:kind]) }
      end

      # Is this id scoped to the given frame? Used to refuse an edit that would
      # cross a Frame boundary in one session.
      def in_frame?(id, frame)
        p = parse(id)
        return false unless p[:ok]
        return true if p[:kind] == :input # frame-independent

        (p[:frame] || p[:id]) == frame.to_s
      end

      def ok(kind, id, **parts)
        { ok: true, kind: kind, id: id }.merge(parts)
      end
      private_class_method :ok

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
