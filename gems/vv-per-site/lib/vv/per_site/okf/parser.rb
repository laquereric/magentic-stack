# frozen_string_literal: true

require "yaml"
require "date"

module Vv
  module PerSite
    module Okf
      # Parse an OKF markdown file: YAML frontmatter (v0.2) plus body, with
      # optional ATX heading sections that become child nodes.
      module Parser
        CTA_HINT = /(needs next|entry point|call to action|\bcta\b)/i
        HEADING = /^(\#{1,3})\s+(.+?)\s*$/

        module_function

        def parse(text)
          text = text.to_s.sub(/^\uFEFF/, "")
          frontmatter = {}
          body = text
          if text.start_with?("---")
            _pre, raw_fm, rest = text.split(/^---\s*$/, 3)
            if rest
              frontmatter = load_frontmatter(raw_fm)
              body = rest.to_s.sub(/\A\s*\n/, "")
            end
          end
          {
            frontmatter: stringify_keys(frontmatter),
            body: body.to_s,
            title: title_of(frontmatter, body),
            doc_type: scalar(frontmatter, "type"),
            description: scalar(frontmatter, "description"),
            tags: Array(frontmatter["tags"] || frontmatter[:tags]),
            status: scalar(frontmatter, "status"),
            okf_version: scalar(frontmatter, "okf_version"),
            sources: Array(frontmatter["sources"] || frontmatter[:sources]),
            generated_by: generated_field(frontmatter, "by"),
            generated_at: generated_field(frontmatter, "at")
          }
        end

        def sections(body)
          lines = body.to_s.lines
          found = []
          current = nil
          buffer = []
          lines.each do |line|
            if (m = line.match(HEADING))
              found << finish_section(current, buffer) if current
              current = { level: m[1].length, title: m[2].strip }
              buffer = []
            elsif current
              buffer << line
            end
          end
          found << finish_section(current, buffer) if current
          # The first H1 is the document title already stored on the parent node.
          found.shift if found.first && found.first[:level] == 1
          found.each_with_index { |s, i| s[:position] = i }
          found
        end

        def slug_for(title)
          title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        end

        def cta_leaf?(body, frontmatter = {})
          kind = scalar(frontmatter, "kind")
          return true if %w[cta cta_leaf].include?(kind.to_s)
          return true if truthy?(frontmatter["cta"] || frontmatter[:cta])

          body.to_s.match?(CTA_HINT)
        end

        def load_frontmatter(raw)
          YAML.safe_load(raw.to_s, permitted_classes: [Date, Time], aliases: true) || {}
        rescue Psych::Exception
          {}
        end

        def stringify_keys(value)
          case value
          when Hash
            value.each_with_object({}) do |(k, v), h|
              h[k.to_s] = stringify_keys(v)
            end
          when Array
            value.map { |v| stringify_keys(v) }
          when Time
            value.iso8601
          when Date
            value.iso8601
          else
            value
          end
        end

        def title_of(frontmatter, body)
          t = scalar(frontmatter, "title")
          return t unless t.empty?

          if (m = body.to_s.match(/^\#\s+(.+)$/))
            return m[1].strip
          end

          ""
        end

        def scalar(hash, key)
          (hash[key] || hash[key.to_sym]).to_s
        end

        def generated_field(frontmatter, key)
          gen = frontmatter["generated"] || frontmatter[:generated]
          return nil unless gen.is_a?(Hash)

          (gen[key] || gen[key.to_sym]).to_s.then { |v| v.empty? ? nil : v }
        end

        def truthy?(value)
          value == true || value.to_s =~ /\A(true|yes|1)\z/i
        end

        def finish_section(current, buffer)
          body = buffer.join.sub(/\A\n/, "").rstrip
          {
            level: current[:level],
            title: current[:title],
            slug: slug_for(current[:title]),
            body: body,
            cta_leaf: cta_leaf?(body)
          }
        end
      end
    end
  end
end
