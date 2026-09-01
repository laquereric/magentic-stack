# frozen_string_literal: true

require "yaml"
require "digest"

module Mmg
  module Adr
    # Parse one ADR file into attributes. Pure: no ActiveRecord, no HTTP, no
    # filesystem beyond the bytes it is handed.
    #
    # Two input forms are accepted, and that is deliberate rather than lax. The
    # canonical form is YAML frontmatter, because metadata a machine has to guess
    # at is metadata that will eventually be guessed wrong. But ADRs 0001-0003
    # were written before this gem existed, with their status and date as prose
    # bullets. Refusing to read them would leave three accepted decisions outside
    # the index -- and a decision the index cannot see is exactly the operational
    # death this gem is here to prevent. So the legacy form parses, and reports
    # `legacy: true` so the gap is visible rather than silently normalised.
    module Document
      module_function

      FRONTMATTER = /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      # "# ADR 0001 -- Make the ownership boundary visible"
      HEADING     = /^\#\s*ADR\s+(\d+)\s*(?:—|–|--|-|:)\s*(.+)$/
      BULLET      = /^-\s*(Status|Date)\s*:\s*(.+)$/i
      SECTION     = /^\#\#\s+(.+?)\s*$/

      # `path` is used for source_path and as the id fallback; it is never read.
      def parse(text, path: nil)
        text = text.to_s
        if (m = FRONTMATTER.match(text))
          from_frontmatter(m[1], m[2], path)
        else
          from_legacy(text, path)
        end
      end

      def from_frontmatter(yaml, body, path)
        # Three cases, not two. `rescue -> {}` used to turn genuine parse
        # failures into an empty mapping, so :unparsable_frontmatter could
        # never name the thing it names. Empty YAML (`nil`) is "no fields",
        # not corrupt. A scalar or list is a mapping failure.
        meta = begin
          YAML.safe_load(yaml, permitted_classes: [Date], aliases: false)
        rescue StandardError => e
          return {
            ok: false,
            reason: :unparsable_frontmatter,
            because: { "detail" => "YAML did not parse", "class" => e.class.name }
          }
        end
        meta = {} if meta.nil?
        unless meta.is_a?(Hash)
          return {
            ok: false,
            reason: :frontmatter_not_a_mapping,
            because: "the --- block is not a YAML mapping (got #{meta.class})"
          }
        end

        attrs = {
          "adr_id"       => str(meta["id"]) || id_from_path(path),
          "title"        => str(meta["title"]),
          "status"       => str(meta["status"])&.downcase,
          "date"         => str(meta["date"]),
          "subject_kind" => str(meta["subject_kind"]),
          "subject"      => str(meta["subject"]),
          "components"   => list(meta["components"]),
          "paths"        => list(meta["paths"]),
          "enforced_by"  => list(meta["enforced_by"]),
          "supersedes"   => list(meta["supersedes"]),
          "superseded_by" => list(meta["superseded_by"]),
          "source_path"  => path&.to_s,
          "body"         => body.to_s,
          "body_digest"  => digest(body),
          "sections"     => sections(body),
          "legacy"       => false
        }
        { ok: true, attributes: attrs }
      end

      # ADRs 0001-0003: heading carries id and title, bullets carry status/date,
      # and there is no declared subject or path list at all. Those come back nil
      # rather than invented -- an absent field is a finding, not a default.
      def from_legacy(text, path)
        head = HEADING.match(text)
        bullets = text.scan(BULLET).to_h { |k, v| [k.downcase, v.strip] }
        attrs = {
          "adr_id"       => head && head[1],
          "title"        => head && head[2].strip,
          "status"       => bullets["status"]&.downcase&.split(/[;,.]/)&.first&.strip,
          "date"         => bullets["date"],
          "subject_kind" => nil,
          "subject"      => nil,
          "components"   => [],
          "paths"        => [],
          "enforced_by"  => [],
          "supersedes"   => [],
          "superseded_by" => [],
          "source_path"  => path&.to_s,
          "body"         => text,
          "body_digest"  => digest(text),
          "sections"     => sections(text),
          "legacy"       => true
        }
        attrs["adr_id"] ||= id_from_path(path)
        { ok: true, attributes: attrs }
      end

      # Nygard's three. Present as a map so a missing one is checkable.
      def sections(body)
        out = {}
        current = nil
        body.to_s.each_line do |line|
          if (m = SECTION.match(line))
            current = m[1].downcase
            out[current] = +""
          elsif current
            out[current] << line
          end
        end
        out.transform_values(&:strip)
      end

      def digest(body) = Digest::SHA256.hexdigest(normalize(strip_preamble_metadata(body)))

      # In a legacy ADR the title heading and the Status / Date / Supersedes
      # bullets ARE metadata -- they are precisely what frontmatter holds. They
      # sit in the body only because there was nowhere else to put them.
      #
      # Excluding them from the digest is what makes migrating an ACCEPTED ADR to
      # frontmatter possible AT ALL. Without it, moving the status out of the
      # prose changes body_digest, the immutability check refuses the save, and
      # the ledger's own rule freezes three records forever in a format the index
      # can barely read. That is not immutability protecting a decision; it is
      # immutability protecting a typography choice.
      #
      # With it, migration is provably content-preserving: the digest before and
      # after is the SAME, and that equality IS the evidence that only metadata
      # moved.
      #
      # Scoped to the PREAMBLE -- the region before the first '## ' section -- so
      # a "- Date:" line inside Context or Consequences is decision text and gets
      # digested like any other prose.
      PREAMBLE_METADATA = /\A\s*(?:\#\s*ADR\s|[-*]\s*(?:Status|Date|Supersedes|Superseded)\b)/i

      def strip_preamble_metadata(body)
        lines = body.to_s.gsub(/\r\n?/, "\n").split("\n")
        first_section = lines.index { |l| l.start_with?("## ") } || lines.length
        preamble = lines[0...first_section].reject { |l| PREAMBLE_METADATA.match?(l) }
        (preamble + Array(lines[first_section..])).join("\n")
      end

      # Digest the MEANING, not the typography. Line endings, trailing spaces, a
      # trailing newline and the number of blank lines between blocks are all
      # invisible in the rendered document, so none of them should read as an
      # amendment to an accepted decision.
      #
      # Deliberately stops there. Re-wrapping the lines WITHIN a paragraph does
      # change the digest, and that is the conservative side to err on: this
      # digest is what makes an edit to a ledger entry visible, so it should
      # over-report a change rather than miss one.
      def normalize(body)
        lines = body.to_s.gsub(/\r\n?/, "\n").split("\n").map(&:rstrip)
        lines.chunk_while { |a, b| a.empty? && b.empty? }
             .flat_map { |run| run.first.empty? ? [""] : run }
             .join("\n").strip
      end

      def id_from_path(path)
        return nil if path.nil?

        File.basename(path.to_s)[/\A(\d+)/, 1]
      end

      def str(value)
        return nil if value.nil?
        s = value.to_s.strip
        s.empty? ? nil : s
      end

      def list(value)
        case value
        when nil then []
        when Array then value.map { |v| str(v) }.compact
        else [str(value)].compact
        end
      end
    end
  end
end
