# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # WHAT REACHES WHAT, READ OFF THE IDS.
    #
    # Every rail on the board carries ! and ? to board-trace.html?trace=<id> and
    # board-inspect.html?explore=<id>, and neither parameter did anything: the
    # trace was a hand-written list of the ten cards X1 happens to reach, so !
    # answered on one card and misled on the other twelve -- same page, same
    # digest, whichever card you pressed.
    #
    # A canonical id is a PATH, and the board has been saying so all along:
    # X1:Y1:R1 is reference R1, of input X1, under frame Y1; Y1:M1:C1 is
    # clarification C1 of meaning M1 under Y1. So reachability is not a fixture,
    # it is a reading of the ids -- four rules, one per relation the board has:
    #
    #   input X          reaches every id that NAMES it   (its references, its carries)
    #   reference X:Y:R  reaches the meanings of its frame (Y:M*)
    #   meaning Y:M      reaches its clarifications        (Y:M:C*)
    #   frame Y          reaches every id that names it
    #
    # ...then the transitive closure, which is what carries ! on an input all
    # the way out to a clarification three hops away.
    #
    # A composed frame falls out of this for free: nothing names Y4 yet, so
    # tracing one truthfully shows a frame that reaches nothing.
    module BoardReach
      module_function

      INPUT     = /\AX\d+\z/
      FRAME     = /\AY\d+\z/
      REFERENCE = /\AX\d+:(Y\d+):R\d+\z/
      MEANING   = /\AY\d+:M\d+\z/

      # The frame an input is read under when its own id does not name one. An
      # input is not read under every frame at once; it is read under the
      # operative one, which is the whole reason the board makes you choose.
      OPERATIVE_FRAME = "Y1"

      NOUNS = [[REFERENCE, "Reference"], [MEANING, "Meaning"],
               [/\AY\d+:M\d+:C\d+\z/, "Clarification"], [/\AX\d+:Y\d+:Z\d+\z/, "Carry"],
               [INPUT, "Input"], [FRAME, "Frame"]].freeze

      # One hop. Everything else is this, repeated.
      def step(id, ids)
        id = id.to_s
        if (m = REFERENCE.match(id))
          ids.select { |o| o.match?(/\A#{Regexp.escape(m[1])}:M\d+\z/) }
        elsif MEANING.match?(id)
          ids.select { |o| o.start_with?("#{id}:C") }
        elsif INPUT.match?(id) || FRAME.match?(id)
          ids.select { |o| o != id && o.split(":").include?(id) }
        else
          []
        end
      end

      # Breadth first, so `distance` can say how far out each card is -- which is
      # what tells an exploration apart from a trace: a trace marks everything it
      # reaches the same, an exploration cares whether a thing was reached
      # directly or by way of something else.
      def from(origin, ids)
        origin = origin.to_s
        seen = {}
        frontier = [origin]
        depth = 0
        until frontier.empty?
          depth += 1
          nxt = []
          frontier.each do |id|
            step(id, ids).each do |o|
              next if o == origin || seen.key?(o)
              seen[o] = depth
              nxt << o
            end
          end
          frontier = nxt
        end
        seen
      end

      def reaches(origin, ids) = from(origin, ids).keys

      def noun(id)
        found = NOUNS.find { |rx, _| rx.match?(id.to_s) }
        found ? found[1] : "Card"
      end

      # The frame this id is read under: the one it names, or the operative one.
      def frame_of(id)
        id.to_s.split(":").find { |s| FRAME.match?(s) } || OPERATIVE_FRAME
      end
    end
  end
end
