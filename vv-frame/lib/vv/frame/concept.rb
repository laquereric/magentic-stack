# frozen_string_literal: true

require_relative "parser"
require_relative "placement"

module Vv
  module Frame
    # One OKF document: its frontmatter, its verbatim body, and its sections.
    #
    # A concept is served whole or by section. It is never rewritten. The text
    # an agent reads here is byte-for-byte the text on disk, because a summary
    # that papers over a constraint is the failure this gem exists to prevent.
    class Concept
      attr_reader :okf_path, :frontmatter, :body, :sections

      def initialize(okf_path:, frontmatter:, body:)
        @okf_path = okf_path
        @frontmatter = frontmatter
        @body = body
        @sections = Parser.sections(body).map { |s| Section.new(okf_path: okf_path, **s) }
      end

      def self.read(root, rel)
        parsed = Parser.parse(File.read(File.join(root, rel), encoding: "UTF-8"))
        return nil if parsed[:frontmatter] == :invalid

        new(okf_path: rel, frontmatter: parsed[:frontmatter], body: parsed[:body])
      end

      def title  = frontmatter["title"].to_s
      def type   = frontmatter["type"].to_s
      def status = frontmatter["status"].to_s
      def tags   = Array(frontmatter["tags"])
      def sources = Array(frontmatter["sources"])
      def section(slug) = sections.find { |s| s.slug == slug.to_s }

      # A character count is a fact; a token count is not. The divisor is a
      # documented estimate and is named as one everywhere it travels.
      CHARS_PER_TOKEN = 4
      def chars = body.length
      def estimated_tokens = (body.length / CHARS_PER_TOKEN.to_f).ceil
    end

    # One `##` section of a concept. Addressed the way vv-per-site addresses it:
    # `doc.md#slug`.
    class Section
      attr_reader :okf_path, :level, :title, :slug, :body, :position

      def initialize(okf_path:, level:, title:, slug:, body:, position: 0)
        @okf_path = okf_path
        @level = level
        @title = title
        @slug = slug
        @body = body
        @position = position
      end

      def path = "#{okf_path}##{slug}"
      def chars = body.length
      def estimated_tokens = (body.length / Concept::CHARS_PER_TOKEN.to_f).ceil

      # The decisions this section links to, in document order.
      def grounded_by
        body.scan(%r{\[ADR (\d{4})[^\]]*\]\(([^)]+)\)}).map { |id, href| { id: id, href: href } }
      end
    end

    # An OKF concept whose type is Architecture Decision: a constraint with a
    # placement, the paths it governs, and the gates that enforce it.
    class Decision < Concept
      def id = frontmatter["adr_id"].to_s
      def placement = @placement ||= Placement.from(frontmatter["frame"])
      def paths = Array(frontmatter["paths"])
      def gates = Array(frontmatter["enforced_by"])
      def unenforced? = frontmatter["unenforced"] == true
      def enforced? = gates.any?
      def resource = frontmatter["resource"].to_s

      # The frame sections this decision grounds, with the reason given.
      def grounds
        section("frame")&.body.to_s.scan(%r{\[([^\]]+)\]\(\.\./frame\.md#([a-z0-9-]+)\)\s*—\s*(.+?)$})
                                  .map { |title, slug, why| { title: title, slug: slug, why: why.strip } }
      end

      # Does this decision govern `path`? A decision governs a path when one of
      # its declared paths is that path or a directory prefix of it. Prefix
      # depth is the specificity, and specificity is a structural fact -- never
      # a relevance score.
      def governs?(path) = specificity_for(path) > 0

      def specificity_for(path)
        p = path.to_s.sub(%r{\A\./}, "")
        best = 0
        paths.each do |declared|
          d = declared.to_s.sub(%r{\A\./}, "").chomp("/")
          next unless p == d || p.start_with?("#{d}/")

          best = [best, d.count("/") + 1].max
        end
        best
      end
    end
  end
end
