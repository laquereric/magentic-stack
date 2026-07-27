# frozen_string_literal: true

module Mmg
  module Acia
    module ComponentMin
      # Draft rewrite logic (brief 4 collaborative) — produces a compact
      # component-call tree referencing vocabulary, without writing HTML yet.
      module Rewriter
        module_function

        # tree: parsed ACIA tree; vocabulary: Minimizer vocabulary array
        def rewrite_tree(tree, vocabulary:)
          names = vocabulary.map { |v| (v[:name] || v["name"]).to_s }
          fps = vocabulary.each_with_object({}) do |v, h|
            fp = v[:fingerprint] || v["fingerprint"]
            h[fp] = v if fp
          end
          out = transform(tree, fps, names)
          { ok: true, tree: out, vocabulary_size: names.size }
        rescue ::StandardError => e
          { ok: false, reason: :rewrite_failed, because: "#{e.class}: #{e.message}" }
        end

        def transform(node, fps, names)
          n = node.is_a?(::Hash) ? node.transform_keys(&:to_sym) : {}
          fp = n[:fingerprint]
          if fp && fps[fp]
            v = fps[fp]
            return {
              kind: "component_ref",
              value: v[:name] || v["name"],
              fingerprint: fp,
              props: { content_role: n[:content_role], original_kind: n[:kind] },
              children: []
            }
          end
          {
            kind: n[:kind],
            value: n[:value],
            sal: n[:sal],
            content_role: n[:content_role],
            children: ::Kernel.Array(n[:children]).map { |c| transform(c, fps, names) }
          }
        end
      end
    end
  end
end
