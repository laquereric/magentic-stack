# frozen_string_literal: true

module Mmg
  module Acia
    # ACIA MARKDOWN MATERIALIZATION (epic_65 Stage 2 -- moved verbatim from Mmg::Sal::Render).
    # A SAL/ACIA node tree -> the git-versioned arc/<arc_id>/<arc_id>.md doc. This is a
    # MATERIALIZATION (a durable .md object), NOT a live host render -- hence CORE, not
    # presentation. Nesting: pane -> H1, list -> heading + bullets, deeper -> nested bullets;
    # action -> checklist. entity_token emits BOTH a navigable markdown file-link (when the IRI
    # resolves to a repo path) AND the raw urn:mm:* IRI in a backtick -- so the doc statically
    # references MD-internal parts AND MM-resident entities, and the mmg-curation concept layer
    # can index it. Pure / never-raise. Mmg::Sal::Render delegates here for backward compat.
    module Markdown
      module_function

      def markdown(node, level = 1)
        return "" unless node.is_a?(::Hash)
        kind = (node[:kind] || node["kind"]).to_s
        val  = (node[:value] || node["value"] || node[:label] || node["label"]).to_s
        kids = ::Kernel.Array(node[:children] || node["children"]).select { |c| c.is_a?(::Hash) }
        case kind
        when "pane"
          body = kids.map { |c| markdown(c, level + 1) }.reject(&:empty?).join("\n\n")
          "# #{val}\n\n#{body}"
        when "list"
          head = val.empty? ? "" : "#{"#" * [level, 6].min} #{val}\n\n"
          body = kids.map { |c| md_item(c, 0) }.reject(&:empty?).join("\n")
          "#{head}#{body}"
        else # entity_token | text | action at top level
          md_item(node, 0)
        end
      end

      # One markdown bullet for a child node (recursive; depth = bullet indent).
      def md_item(node, depth)
        pad  = "  " * depth
        kind = (node[:kind] || node["kind"]).to_s
        val  = (node[:value] || node["value"] || node[:label] || node["label"]).to_s
        kids = ::Kernel.Array(node[:children] || node["children"]).select { |c| c.is_a?(::Hash) }
        line =
          case kind
          when "entity_token" then "#{pad}- #{val}#{md_ref(node)}"
          when "action"       then "#{pad}- [ ] **#{val}**"
          when "list"         then "#{pad}- **#{val}**"
          else                     "#{pad}- #{val}"
          end
        sub = kids.map { |c| md_item(c, depth + 1) }.reject(&:empty?).join("\n")
        sub.empty? ? line : "#{line}\n#{sub}"
      end

      # STATIC references for an entity_token: BOTH a navigable markdown file-link (when the IRI
      # resolves to a repo path -- urn:mm:file:<path> -> [path](/path)) AND the raw urn:mm:* IRI in a
      # backtick (graph-groundable + mmg-curation concept anchor), plus the semantic_role tag.
      def md_ref(node)
        iri  = (node[:entity_iri] || node["entity_iri"]).to_s
        role = (node[:semantic_role] || node["semantic_role"]).to_s
        hint = (node[:hint] || node["hint"]).to_s
        return (role.empty? ? "" : "  _(#{role})_") if iri.empty?
        parts = []
        link = iri_path(iri) || (hint.match?(/\A[\w.\/-]+\.\w+\z/) ? hint : nil)
        parts << "[#{link}](/#{link})" if link
        parts << "`#{iri}`"
        parts << "_(#{role})_" unless role.empty?
        "  " + parts.join(" ")
      end

      # If the IRI encodes a repo path (urn:mm:file:<path>), return the path; else nil.
      def iri_path(iri)
        m = iri.to_s.match(/\Aurn:mm:file:(.+)\z/)
        m && m[1]
      end
    end
  end
end
