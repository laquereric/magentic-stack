# frozen_string_literal: true

require "json"

module Vv
  module DependencyOrch
    # The seam between computing the graph and looking at it.
    #
    # It exists from stage 1, before any canvas, and that ordering is the point:
    # a graph you can only look at is one you cannot diff, grep, or put in CI.
    # When the canvas arrives it renders THIS, and the gate is that a board may
    # not assert an edge the export does not carry.
    #
    # JSON first, mermaid second, and the second is derived from the first --
    # not assembled separately -- so the two cannot drift into disagreeing about
    # what the graph contains.
    module Export
      FORMATS = %i[json mermaid].freeze

      module_function

      def call(graph, format: :json, notes: [])
        format = format.to_sym
        unless FORMATS.include?(format)
          return Envelope.refuse("unsupported_kind", "format must be json or mermaid, got #{format.inspect}")
        end

        Envelope.never_raise do
          doc = document(graph, notes)
          body = format == :json ? JSON.pretty_generate(doc) : mermaid(doc)
          Envelope.ok(format: format, body: body)
        end
      end

      def document(graph, notes)
        {
          "format" => 1,
          "generator" => "vv-dependency-orch #{VERSION}",
          # Notes ride WITH the graph rather than being printed alongside it.
          # An export that omits "the daemon was unreachable" is an export whose
          # empty placement lists mean something different from what they look
          # like, and in CI nobody is there to have seen the warning.
          "notes" => notes,
          "resources" => graph.resources.values.map { |r| stringify(r.to_h) },
          "edges" => graph.edges.map { |e| stringify(e.to_h) }
        }
      end

      # Mermaid is a rendering of the document, and deliberately a lossy one.
      # It shows shape; the JSON is the fact. Anything that needs to be exact
      # reads the JSON.
      def mermaid(doc)
        lines = ["graph LR"]

        doc["resources"].each do |resource|
          id = node_id(resource["digest"])
          label = [resource["names"].first, Identity.short(resource["digest"])].compact.join("\\n")
          shape = case resource["index_digest"]
                  when false then ["[(", ")]"]   # no index digest: unpublished, or a lone manifest
                  when nil then ["([", "])"]     # not determined
                  else ["[", "]"]
                  end
          lines << "  #{id}#{shape[0]}\"#{escape(label)}\"#{shape[1]}"
        end

        doc["edges"].each do |edge|
          arrow = edge["kind"] == "declares" ? "==>" : "-->"
          label = edge["kind"]
          lines << "  #{node_id(edge['from'])} #{arrow}|#{label}| #{node_id(edge['to'])}"
        end

        lines.join("\n")
      end

      def node_id(node)
        "n#{node.to_s.gsub(/[^a-zA-Z0-9]/, '_')[0, 40]}"
      end

      def escape(text) = text.to_s.gsub('"', "'")

      # Symbol keys are fine in Ruby and are noise in a diffable artefact. JSON
      # has one kind of key, so the document has one kind of key.
      def stringify(value)
        case value
        when Hash then value.to_h { |k, v| [k.to_s, stringify(v)] }
        when Array then value.map { |v| stringify(v) }
        when Symbol then value.to_s
        when Time then value.utc.iso8601
        else value
        end
      end
    end
  end
end
