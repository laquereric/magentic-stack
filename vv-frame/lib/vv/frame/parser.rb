# frozen_string_literal: true

require "yaml"
require "date"

module Vv
  module Frame
    # Parse one Open Knowledge Format document: YAML frontmatter (v0.2) plus a
    # markdown body whose ATX headings are the document's sections.
    #
    # This mirrors the shape vv-per-site's OKF parser reads, deliberately: a
    # bundle this gem accepts is a bundle that gem can seed. It does not mutate
    # what it reads -- see Vv::Frame::REFUSED_OPERATIONS.
    module Parser
      HEADING = /^(\#{1,3})[ \t]+(.+?)[ \t]*$/
      module_function

      def parse(text)
        text = text.to_s.sub(/\A﻿/, "")
        frontmatter = {}
        body = text
        if text.start_with?("---")
          _pre, raw, rest = text.split(/^---[ \t]*$/, 3)
          if rest
            frontmatter = load_frontmatter(raw)
            body = rest.to_s.sub(/\A\s*\n/, "")
          end
        end
        { frontmatter: stringify(frontmatter), body: body.to_s }
      end

      # Sections, in document order. The leading H1 is the document's own title
      # and is not a section of it.
      def sections(body)
        found = []
        current = nil
        buffer = []
        body.to_s.each_line do |line|
          if (m = line.match(HEADING))
            found << finish(current, buffer) if current
            current = { level: m[1].length, title: m[2].strip }
            buffer = []
          elsif current
            buffer << line
          end
        end
        found << finish(current, buffer) if current
        found.shift if found.first && found.first[:level] == 1
        found.each_with_index { |s, i| s[:position] = i }
        found
      end

      # The anchor a markdown renderer gives a heading, and the slug vv-per-site
      # stores. One rule, so a link written here resolves in both.
      def slug_for(title)
        title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      end

      def load_frontmatter(raw)
        YAML.safe_load(raw.to_s, permitted_classes: [Date, Time], aliases: true) || {}
      rescue Psych::Exception
        :invalid
      end

      def stringify(value)
        case value
        when Hash  then value.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then value.map { |v| stringify(v) }
        when Date, Time then value.iso8601
        else value
        end
      end

      def finish(current, buffer)
        {
          level: current[:level],
          title: current[:title],
          slug: slug_for(current[:title]),
          body: buffer.join.sub(/\A\n/, "").rstrip
        }
      end
    end
  end
end
