# frozen_string_literal: true

module Vv
  module Frame
    # A budgeted load for the sharp part of a context window.
    #
    # The window is not the budget. The smart zone is roughly 100K tokens
    # however large the window is, attention is U-shaped, and what the middle
    # loses first is constraints. So a pack is small on purpose, ordered by
    # structure, and served verbatim.
    #
    # Two rules do the work:
    #
    #   Nothing is summarised. A constraint the reader never saw the original
    #   of is the defect this exists to prevent, so a section either fits whole
    #   or does not travel.
    #
    #   Nothing is dropped silently. Everything the budget could not carry is
    #   named in the pack itself -- id, title and estimated size -- so a reader
    #   knows its context is partial. A pack that hides its omissions reads as
    #   complete, which is worse than one that is obviously short.
    class ContextPack
      # The practical edge of the smart zone, as reported rather than measured
      # here. Named as an estimate because that is what it is.
      SMART_ZONE_TOKENS = 100_000

      attr_reader :parts, :dropped, :budget_tokens

      def initialize(parts:, dropped:, budget_tokens:)
        @parts = parts
        @dropped = dropped
        @budget_tokens = budget_tokens
      end

      # Build a pack for a path, optionally led by a trajectory.
      #
      # Order is structural and therefore stable: the trajectory first (it is
      # what orients the reader), then the named frame sections, then the
      # decisions governing the path, most specific first, ties on id.
      def self.build(bundle:, path: nil, trajectory: nil, sections: nil,
                     budget_tokens: SMART_ZONE_TOKENS)
        budget = budget_tokens.to_i
        return refuse(:budget_not_positive, budget.to_s) unless budget.positive?

        candidates = []
        if trajectory
          md = trajectory.to_markdown
          candidates << part(:trajectory, trajectory.slice.key, "Trajectory", md)
        end

        chosen_sections = sections ? bundle.sections.select { |s| Array(sections).include?(s.slug) }
                                   : bundle.sections
        chosen_sections.each do |s|
          candidates << part(:section, s.slug, s.title, "## #{s.title}\n\n#{s.body}\n")
        end

        decisions = path ? bundle.for_path(path) : bundle.decisions
        decisions.each do |d|
          candidates << part(:decision, d.id, d.title, d.body)
        end

        taken = []
        dropped = []
        spent = 0
        candidates.each do |c|
          if spent + c[:estimated_tokens] <= budget
            taken << c
            spent += c[:estimated_tokens]
          else
            dropped << c.merge(reason: :budget_exhausted)
          end
        end

        { ok: true, pack: new(parts: taken, dropped: dropped, budget_tokens: budget) }
      end

      def self.part(kind, id, title, body)
        { kind: kind, id: id.to_s, title: title.to_s, body: body,
          estimated_tokens: (body.length / Concept::CHARS_PER_TOKEN.to_f).ceil }
      end

      def self.refuse(reason, because) = { ok: false, reason: reason, because: because }

      def included = parts.map { |p| { kind: p[:kind], id: p[:id], title: p[:title] } }
      def estimated_tokens = parts.sum { |p| p[:estimated_tokens] }
      def within_smart_zone? = estimated_tokens <= SMART_ZONE_TOKENS
      def complete? = dropped.empty?

      # The pack as one document. When anything was dropped, the omissions are
      # part of the document -- a reader has to be able to see that it is
      # holding a partial record.
      def to_markdown
        out = parts.map { |p| p[:body].rstrip }.join("\n\n---\n\n")
        out = +"#{out}\n"
        out << omissions_note unless complete?
        out
      end

      def omissions_note
        lines = +"\n---\n\n## Omitted from this pack\n\n"
        lines << "This context is **partial**. #{dropped.size} item(s) did not fit a " \
                 "#{budget_tokens}-token budget and are named here rather than dropped silently. " \
                 "Read them from the bundle before relying on a constraint being absent.\n\n"
        dropped.each do |d|
          lines << "* #{d[:kind]} `#{d[:id]}` — #{d[:title]} (~#{d[:estimated_tokens]} tokens, #{d[:reason]})\n"
        end
        lines
      end
    end
  end
end
