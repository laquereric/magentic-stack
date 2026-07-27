# frozen_string_literal: true

require "cgi"
require "json"
require "fileutils"

module Mmg
  module Acia
    module ComponentMin
      # Brief 4: rewrite landing trees as REFERENCES into the covering vocabulary.
      # Emits component-call trees + sample HTML (data-acia-component markers).
      # Full 53-page HTML land is SUPERDEV; this drafts the logic + one sample.
      module Rewriter
        module_function

        # tree: parsed ACIA tree; vocabulary: covering-set array
        def rewrite_tree(tree, vocabulary:)
          vocab = ::Kernel.Array(vocabulary)
          fps = vocab.each_with_object({}) do |v, h|
            v = v.is_a?(::Hash) ? v.transform_keys(&:to_sym) : {}
            fp = v[:fingerprint]
            h[fp] = v if fp
          end
          names = vocab.map { |v|
            v = v.is_a?(::Hash) ? v.transform_keys(&:to_sym) : {}
            (v[:name] || "").to_s
          }.reject(&:empty?)
          stats = { refs: 0, residual_nodes: 0, component_refs: [] }
          out = transform(tree, fps, stats)
          {
            ok: true,
            tree: out,
            vocabulary_size: names.size,
            ref_count: stats[:refs],
            residual_nodes: stats[:residual_nodes],
            component_refs: stats[:component_refs].uniq
          }
        rescue ::StandardError => e
          { ok: false, reason: :rewrite_failed, because: "#{e.class}: #{e.message}" }
        end

        def transform(node, fps, stats)
          n = node.is_a?(::Hash) ? node.transform_keys(&:to_sym) : {}
          fp = n[:fingerprint]
          if fp && fps[fp]
            v = fps[fp]
            name = (v[:name] || v["name"]).to_s
            stats[:refs] += 1
            stats[:component_refs] << name
            return {
              kind: "component_ref",
              value: name,
              fingerprint: fp,
              props: {
                content_role: n[:content_role],
                original_kind: n[:kind],
                source: v[:source]
              },
              children: [] # concrete markup deduped into vocabulary definition
            }
          end
          stats[:residual_nodes] += 1
          {
            kind: n[:kind],
            value: n[:value],
            sal: n[:sal],
            content_role: n[:content_role],
            html_tag: n[:html_tag],
            children: ::Kernel.Array(n[:children]).map { |c| transform(c, fps, stats) }
          }
        end

        # Emit compact HTML fragment for a rewritten tree (sample / draft).
        def tree_to_html(node, indent: 0)
          n = node.is_a?(::Hash) ? node.transform_keys(&:to_sym) : {}
          pad = "  " * indent
          if n[:kind].to_s == "component_ref"
            name = CGI.escapeHTML(n[:value].to_s)
            fp = CGI.escapeHTML(n[:fingerprint].to_s)
            role = CGI.escapeHTML((n.dig(:props, :content_role) || "").to_s)
            return "#{pad}<acia-component name=\"#{name}\" fingerprint=\"#{fp}\" role=\"#{role}\"></acia-component>\n"
          end
          if n[:kind].to_s == "text"
            return "#{pad}#{CGI.escapeHTML(n[:value].to_s)}\n"
          end
          tag = (n[:html_tag] || tag_for_kind(n[:kind])).to_s
          attrs = []
          attrs << "data-acia-kind=\"#{CGI.escapeHTML(n[:kind].to_s)}\"" if n[:kind]
          attrs << "data-content-role=\"#{CGI.escapeHTML(n[:content_role].to_s)}\"" if n[:content_role]
          open = attrs.empty? ? "<#{tag}>" : "<#{tag} #{attrs.join(' ')}>"
          kids = ::Kernel.Array(n[:children])
          if kids.empty?
            "#{pad}#{open}</#{tag}>\n"
          else
            body = kids.map { |c| tree_to_html(c, indent: indent + 1) }.join
            "#{pad}#{open}\n#{body}#{pad}</#{tag}>\n"
          end
        end

        def tag_for_kind(kind)
          {
            "surface" => "div", "pane" => "section", "header" => "header",
            "footer" => "footer", "list" => "ul", "item" => "li",
            "link" => "a", "action" => "button", "text" => "span",
            "semantic_text" => "p", "table" => "table", "row" => "tr",
            "cell" => "td", "modal" => "dialog", "details" => "details",
            "entity_token" => "span", "enqueue" => "form"
          }[kind.to_s] || "div"
        end

        # Rewrite all parsed trees; write JSON refs + one sample HTML.
        def rewrite_all(parse_result, vocabulary:, out_dir:)
          ::FileUtils.mkdir_p(out_dir)
          pages = []
          sample_html = nil
          sample_site = nil
          ::Kernel.Array(parse_result[:trees]).each do |row|
            next unless row[:ok] && row[:tree]

            rw = rewrite_tree(row[:tree], vocabulary: vocabulary)
            next unless rw[:ok]

            site = row[:site].to_s
            payload = {
              site: site,
              source: row[:path],
              ref_count: rw[:ref_count],
              residual_nodes: rw[:residual_nodes],
              component_refs: rw[:component_refs],
              tree: rw[:tree]
            }
            path = ::File.join(out_dir, "#{site}.rewrite.json")
            ::File.write(path, ::JSON.pretty_generate(payload))
            pages << {
              site: site,
              path: path,
              ref_count: rw[:ref_count],
              residual_nodes: rw[:residual_nodes],
              component_refs: rw[:component_refs]
            }
            if sample_html.nil? && rw[:ref_count].to_i > 0
              sample_site = site
              sample_html = wrap_sample_html(site, rw[:tree])
            end
          end

          sample_path = nil
          if sample_html
            sample_path = ::File.join(out_dir, "#{sample_site}.rewrite.sample.html")
            ::File.write(sample_path, sample_html)
          end

          total_refs = pages.sum { |p| p[:ref_count].to_i }
          total_residual = pages.sum { |p| p[:residual_nodes].to_i }
          denom = total_refs + total_residual
          reuse_ratio = denom.positive? ? (total_refs.to_f / denom).round(4) : 0.0

          {
            ok: true,
            n_pages: pages.size,
            pages: pages,
            sample_site: sample_site,
            sample_path: sample_path,
            total_refs: total_refs,
            total_residual: total_residual,
            reuse_ratio: reuse_ratio,
            vocabulary_size: ::Kernel.Array(vocabulary).size
          }
        rescue ::StandardError => e
          { ok: false, reason: :rewrite_all_failed, because: "#{e.class}: #{e.message}" }
        end

        def wrap_sample_html(site, tree)
          body = tree_to_html(tree, indent: 2)
          <<~HTML
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>#{CGI.escapeHTML(site)} — ACIA component-ref rewrite (sample)</title>
              <style>
                acia-component {
                  display: block;
                  border: 1px dashed #6A1FD0;
                  padding: 0.75rem;
                  margin: 0.5rem 0;
                  background: #f7f0ff;
                  font-family: ui-monospace, monospace;
                  font-size: 0.9rem;
                }
                acia-component::before {
                  content: "ref: " attr(name);
                  font-weight: 600;
                  color: #4A00B7;
                }
              </style>
            </head>
            <body data-acia-rewrite="component_ref" data-site="#{CGI.escapeHTML(site)}">
            <!-- Draft sample: concrete markup collapsed to covering vocabulary refs.
                 SUPERDEV lands full corpus rewrites. -->
            #{body}
            </body>
            </html>
          HTML
        end
      end
    end
  end
end
