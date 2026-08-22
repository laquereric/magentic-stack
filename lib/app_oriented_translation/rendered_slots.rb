# frozen_string_literal: true

module AppOrientedTranslation
  # Fills the ACIA render references in a materialized page layout.
  #
  # THE CONSTRAINT THAT DECIDES THE DESIGN
  # --------------------------------------
  # Profile 9 derives every node cid from the WHOLE-DOCUMENT digest:
  #
  #   node_cid = sha256(acia_digest + ":" + node_id)[0,16]
  #
  # So a subtree re-rendered on its own would mint different cids, and the page
  # would carry provenance that matches nothing. `Renderer.render_node` is also
  # a private class method -- the seam is the document, deliberately.
  #
  # Therefore a reference is never re-rendered. It is FILLED with the renderer's
  # own output for that node, sliced out of the single document render by
  # `data-ux-node-id`. The bytes inside a slot are exactly the bytes Profile 9
  # produced, so cids, digests, and the hydration correlation all survive the
  # move to a materialized layout.
  module RenderedSlots
    module_function

    # @param html [String] the Profile 9 renderer's output for the whole document
    # @param node_ids [Array<String>] the nodes the layout references
    # @return [Hash] { ok: true, slots: { slot_name => html } }
    def extract(html:, node_ids:)
      return refuse(:no_html, "expected rendered HTML") unless html.is_a?(String) && !html.empty?

      ids = Array(node_ids).map(&:to_s).reject(&:empty?)
      return refuse(:no_node_ids, "expected at least one node id to extract") if ids.empty?

      slots = {}
      missing = []
      ids.each do |id|
        fragment = slice(html, id)
        if fragment.nil?
          missing << id
        else
          slots[AciaToHerb.slot_name(id)] = fragment
        end
      end

      # Fail closed: a page with an unfilled reference is a page with a hole in
      # it, and a hole is worse than a refusal because it still looks rendered.
      unless missing.empty?
        return refuse(:unresolved_node_reference,
                      "the layout references node(s) absent from the rendered document: #{missing.join(', ')}")
      end

      { ok: true, slots: slots }
    end

    # nodeId -> the renderer's OWN open-tag attribute string.
    #
    # A materialized element must carry the renderer's full attribute contract,
    # not a readable subset. The component runtime and the host Layout
    # Projection both key on it -- drop `data-ux-acia-digest`,
    # `data-ux-token-digest`, `data-ux-content-role` or `aria-label` and the
    # element still LOOKS right while silently failing to hydrate, which is how
    # a five-track grid becomes a stack with no error anywhere.
    #
    # So the attributes are carried across verbatim rather than regenerated.
    # The cid in particular cannot be recomputed from the tree at all: it is
    # derived from the whole-document digest.
    def node_attrs(html:)
      return {} unless html.is_a?(String)

      html.scan(/<[a-zA-Z][a-zA-Z0-9]*\s+(data-ux-node-cid="[^"]*"\s+data-ux-node-id="([^"]*)"[^>]*?)>/)
          .to_h { |attrs, id| [id, attrs.strip] }
    end

    # The renderer's `.ux-render-root` opening tag, verbatim.
    #
    # The component runtime scans for `.ux-render-root` and hydrates what it
    # finds inside. A materialized layout that is not wrapped in it renders
    # perfectly valid markup that never hydrates -- no components, no host
    # Layout Projection, no grid -- and reports no error, because from the
    # runtime's point of view there is simply nothing on the page to do.
    def render_root_tag(html:)
      return nil unless html.is_a?(String)

      html[/<div class="ux-render-root"[^>]*>/]
    end

    # Balanced slice of the element carrying data-ux-node-id="<id>".
    #
    # The input is machine-generated markup from one known emitter -- every
    # element is `<tag attrs>...</tag>`, there are no void or self-closing
    # elements in the component output, and attribute values are escaped. A tag
    # counter is therefore sufficient and, unlike a regex, cannot stop at the
    # first nested close.
    def slice(html, node_id)
      anchor = %(data-ux-node-id="#{node_id}")
      at = html.index(anchor)
      return nil if at.nil?

      open_at = html.rindex("<", at)
      return nil if open_at.nil?

      tag = html[open_at + 1..].to_s[/\A[a-zA-Z][a-zA-Z0-9]*/]
      return nil if tag.nil?

      open_re = /<#{tag}(?=[\s>])/
      close = "</#{tag}>"
      depth = 0
      cursor = open_at

      while cursor < html.length
        next_open = html.index(open_re, cursor)
        next_close = html.index(close, cursor)
        return nil if next_close.nil?

        if next_open && next_open < next_close
          depth += 1
          cursor = next_open + tag.length + 1
        else
          depth -= 1
          cursor = next_close + close.length
          return html[open_at...cursor] if depth.zero?
        end
      end
      nil
    end

    def refuse(reason, because) = { ok: false, reason: reason, because: because }
    private_class_method :refuse
  end

  # What `acia.<slot>` resolves against in a materialized layout.
  #
  # HERB output tags carry a typed PATH, not a method call, so the binding is a
  # closed set of pre-resolved slots rather than an object with behaviour. An
  # unknown path raises here instead of rendering empty: a silently blank column
  # looks like a design decision, and this is the one place that mistake would
  # be invisible.
  class SlotBinding
    def initialize(slots)
      @slots = (slots || {}).transform_keys(&:to_s)
    end

    def slot?(name) = @slots.key?(name.to_s)

    def names = @slots.keys.sort

    def respond_to_missing?(name, _private = false) = slot?(name)

    def method_missing(name, *args)
      key = name.to_s
      unless @slots.key?(key)
        raise KeyError, "unknown ACIA slot #{key.inspect}; the layout references a node the render did not " \
                        "provide. Known slots: #{names.join(', ')}"
      end
      raise ArgumentError, "ACIA slot #{key.inspect} takes no arguments" unless args.empty?

      @slots[key].html_safe
    end
  end
end
