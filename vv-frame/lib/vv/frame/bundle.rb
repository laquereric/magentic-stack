# frozen_string_literal: true

require_relative "concept"

module Vv
  module Frame
    # A loaded OKF bundle: one frame document and its decision concepts.
    #
    # Every reader on this class is a lookup over structure -- a path prefix, a
    # declared slug, an id. Nothing here scores, ranks or rewrites. Ordering,
    # where it exists, is by specificity then id, so the same question asked
    # twice returns the same answer in the same order.
    class Bundle
      attr_reader :root, :frame, :decisions, :index

      def initialize(root:, frame:, decisions:, index: nil)
        @root = root
        @frame = frame
        @decisions = decisions.sort_by(&:id)
        @index = index
        @by_id = @decisions.to_h { |d| [d.id, d] }
      end

      def self.load(root)
        root = File.expand_path(root.to_s)
        return { ok: false, reason: :bundle_missing, because: root } unless Dir.exist?(root)

        frame_path = File.join(root, "frame.md")
        return { ok: false, reason: :frame_missing, because: frame_path } unless File.file?(frame_path)

        frame = Concept.read(root, "frame.md")
        return { ok: false, reason: :frontmatter_invalid, because: "frame.md" } if frame.nil?

        decisions = []
        bad = []
        Dir[File.join(root, "adr", "*.md")].sort.each do |abs|
          rel = abs.sub("#{root}/", "")
          d = Decision.read(root, rel)
          d.nil? ? bad << rel : decisions << d
        end
        return { ok: false, reason: :frontmatter_invalid, because: bad.join(", ") } if bad.any?

        index = File.file?(File.join(root, "index.md")) ? Concept.read(root, "index.md") : nil
        { ok: true, bundle: new(root: root, frame: frame, decisions: decisions, index: index) }
      end

      def decision(id)
        d = @by_id[id.to_s.rjust(4, "0")]
        d ? { ok: true, decision: d } : { ok: false, reason: :unknown_decision, because: id.to_s }
      end

      def sections = frame.sections
      def section(slug) = frame.section(slug)

      # Decisions that govern a path, most specific first. Ties break on id, so
      # the order is a property of the bundle and not of the filesystem.
      def for_path(path)
        decisions.map { |d| [d.specificity_for(path), d] }
                 .select { |spec, _| spec.positive? }
                 .sort_by { |spec, d| [-spec, d.id] }
                 .map(&:last)
      end

      # Decisions that reach a frame section, in id order.
      def for_section(slug)
        s = slug.to_s
        decisions.select { |d| d.grounds.any? { |g| g[:slug] == s } }
      end

      def unenforced = decisions.select(&:unenforced?)
      def enforced = decisions.select(&:enforced?)

      # The futures gauge: paid entries against declared liabilities.
      def ledger
        { enforced: enforced.size, unenforced: unenforced.size,
          ungated: decisions.reject { |d| d.enforced? || d.unenforced? }.size,
          total: decisions.size }
      end

      # Every placement finding in the bundle, decision by decision. A list of
      # findings, never a score.
      def findings
        decisions.flat_map do |d|
          d.placement.findings.map { |f| f.merge(adr_id: d.id, title: d.title) }
        end
      end

      def gates = decisions.flat_map(&:gates).uniq.sort
      def paths = decisions.flat_map(&:paths).uniq.sort
    end
  end
end
