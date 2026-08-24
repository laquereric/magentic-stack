# frozen_string_literal: true

module AppOrientedTranslation
  # ACIA tree -> HERB page layout.
  #
  # WHY THIS EXISTS
  # ---------------
  # A rendered ACIA document is one opaque blob of generated markup. A Rails
  # developer opening the view cannot see the page: no landmarks, no columns,
  # nothing to edit. That is fine while a page is being discovered (fail fast,
  # ugly, JIT) and wrong once it has a shape worth designing.
  #
  # This converter materializes the TOP of the tree -- the page layout -- as
  # static, readable HERB, and leaves everything below a cut as ACIA render
  # REFERENCES. A designer gets a file whose structure matches what they see;
  # the parts still churning stay generated.
  #
  #   depth 0   PageShell            -> static <main>
  #   depth 1   ScopeTrail, title,
  #             banner, filter bar,
  #             board PanelFrame,
  #             explore PanelFrame   -> static elements
  #   depth 2+  the five columns,
  #             the explore items    -> <%= acia.<slot> %> references
  #
  # WHAT IS NOT DONE HERE
  # ---------------------
  # Nothing is re-rendered. A referenced subtree is filled with the Profile 9
  # renderer's OWN output for that node, because every node cid is derived from
  # the whole-document digest -- re-rendering a subtree in isolation would mint
  # different cids and silently break provenance. See RenderedSlots.
  #
  # HERB, per rails-acia-jit/docs/HERB-PROCESSOR.md, is an ERB-SHAPED
  # DECLARATIVE language, not ERB and not a Ruby subset: a `<%# HERB/1 %>`
  # prologue, control tags limited to if/else/end and `for item in collection`,
  # and output tags that carry only a typed path. So a reference is spelled as a
  # typed slot path, never a method call -- `<%= acia.brd_col_inputs %>`, not
  # `<%= render_node(...) %>`. `export_erb` is the documented ONE-WAY projection
  # to ERB for today's ActionView path; nothing travels back.
  module AciaToHerb
    module_function

    PROLOGUE = "<%# HERB/1 %>"

    # Profile 9 semanticRole -> element, mirroring the renderer's own map so a
    # materialized layout keeps the tag the generated markup would have used.
    SEMANTIC_TAG = {
      "landmark" => "main", "heading" => "h2", "list" => "ul", "listitem" => "li",
      "article" => "article", "figure" => "figure", "form" => "form", "input" => "div",
      "button" => "button", "status" => "div", "alert" => "div", "dialog" => "dialog",
      "table" => "table", "timeline" => "ol"
    }.freeze

    DEFAULT_CUT = 2

    # @param acia [Hash] a Profile 9 ACIA document (root or rootNode)
    # @param cut [Integer] first depth rendered as a reference rather than markup
    # @return [Hash] { ok: true, herb:, slots:, materialized:, referenced: }
    # @param render_root [String, nil] the renderer's `.ux-render-root` opening
    #   tag. REQUIRED for a page that hydrates: the component runtime scans for
    #   that element, so a layout emitted outside it is inert markup that fails
    #   silently -- valid HTML, no components, no grid, no error.
    def convert(acia:, cut: DEFAULT_CUT, node_attrs: {}, render_root: nil)
      root = acia.is_a?(Hash) ? (acia["root"] || acia["rootNode"] || acia) : nil
      return refuse(:no_acia_root, "expected an ACIA document with a root or rootNode") unless root.is_a?(Hash)
      return refuse(:invalid_cut, "cut must be a positive Integer, got #{cut.inspect}") unless cut.is_a?(Integer) && cut.positive?

      slots = []
      body = emit(root, 0, cut, slots, 1, node_attrs || {})
      return refuse(:no_slots, "cut #{cut} left nothing referenced; the whole tree would be frozen into markup") if slots.empty?

      body = "#{render_root}\n#{body}</div>\n" if render_root

      { ok: true, cut: cut, hydratable: !render_root.nil?,
        herb: "#{PROLOGUE}\n#{header_comment(root, cut, slots)}#{body}",
        slots: slots, materialized: count_materialized(root, 0, cut), referenced: slots.size }
    end

    # The ONE-WAY projection to ERB. HERB is the artifact a designer edits; this
    # is what ActionView renders today. Never parse the result back as HERB.
    #
    # The projection is deliberately almost empty: a HERB output tag is a typed
    # path, and `acia.<slot>` is already valid ERB against a SlotBinding local.
    # Only the prologue changes, so the two forms stay legible against each
    # other and a diff between them shows real drift rather than transport.
    #
    # The prologue check is the trust gate: only source this converter emitted
    # reaches ERB. Arbitrary text is refused, per the HERB processor's rule that
    # no attacker-influenced template source is ever evaluated.
    def export_erb(herb:)
      return refuse(:no_herb, "expected HERB/1 source; only source AciaToHerb emitted may be exported") unless
        herb.is_a?(String) && herb.start_with?(PROLOGUE)

      { ok: true, erb: herb.sub(PROLOGUE, "<%# generated from HERB/1 -- ONE-WAY export; edit the .herb, not this %>") }
    end

    # nodeId -> HERB slot path. Dashes are not path-safe in a typed path.
    def slot_name(node_id)
      node_id.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end

    def emit(node, depth, cut, slots, indent, node_attrs = {})
      pad = "  " * indent
      node_id = node["nodeId"].to_s
      kind = node["componentKind"].to_s
      slt = node["slt"] || {}
      children = Array(node["children"])

      # At or below the cut the node is a reference, not markup.
      if depth >= cut
        slot = slot_name(node_id)
        slots << { slot: slot, node_id: node_id, kind: kind, depth: depth }
        return "#{pad}<%= acia.#{slot} %>\n"
      end

      # A childless node above the cut is emitted as a REFERENCE, not a wrapper.
      # Wrapping it would render the same node twice -- once as the materialized
      # shell and once inside its own slot -- which duplicates its cid and its
      # visible content.
      if children.empty?
        slot = slot_name(node_id)
        slots << { slot: slot, node_id: node_id, kind: kind, depth: depth, leaf: true }
        return "#{pad}<%= acia.#{slot} %>\n"
      end

      tag = SEMANTIC_TAG[slt["semanticRole"].to_s] || "div"
      title = node.dig("props", "valueJson", "title").to_s

      # The renderer's own attribute string, verbatim. Regenerating a readable
      # subset drops data-ux-acia-digest / token-digest / content-role /
      # aria-label, and the element then fails to hydrate while still looking
      # correct in the markup.
      carried = node_attrs[node_id]
      attrs = if carried.to_s.empty?
                [%(data-ux-node-id="#{node_id}"), %(data-ux-component-kind="#{kind}")]
              else
                [carried]
              end
      # Added for the reader, not the runtime: these say why the element sits
      # where it does. responsiveSignature is what the host Layout Projection
      # reads to pick a recipe.
      attrs << %(data-ux-layout-kind="#{slt['layoutKind']}") unless slt["layoutKind"].to_s.empty?
      sig = slt["responsiveSignature"].to_s
      attrs << %(data-ux-responsive-signature="#{sig}") unless sig.empty? || sig == "default"

      inner = +""
      inner << %(#{pad}  <span data-ux-label>#{escape(title)}</span>\n) unless title.empty?
      children.each { |c| inner << emit(c, depth + 1, cut, slots, indent + 1, node_attrs) }

      "#{pad}<#{tag} #{attrs.join(' ')}>\n#{inner}#{pad}</#{tag}>\n"
    end

    def count_materialized(node, depth, cut)
      return 0 if depth >= cut

      1 + Array(node["children"]).sum { |c| count_materialized(c, depth + 1, cut) }
    end

    def header_comment(root, cut, slots)
      "<%# page layout materialized from ACIA #{root['nodeId']} at cut #{cut}; " \
        "#{slots.size} subtree(s) stay ACIA render references %>\n"
    end

    def escape(str)
      str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end

    def refuse(reason, because) = { ok: false, reason: reason, because: because }
    private_class_method :refuse
  end
end
