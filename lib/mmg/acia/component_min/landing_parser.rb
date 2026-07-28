# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "digest"
require "json"
require "time"

module Mmg
  module Acia
    module ComponentMin
      # Parse landing HTML → ACIA-shaped component tree with SAL typing (brief 1).
      # Never-raise public API. Uses a lightweight HTML tokenizer (stdlib only).
      module LandingParser
        module_function

        SKIP_TAGS = %w[script style noscript svg path meta link br hr].freeze

        # Parse one file. Returns { ok:, tree:, path:, site:, metrics: }
        def parse_file(path)
          html = ::File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace, replace: "?")
          site = path.to_s[%r{gems/(app-[^/]+)/}, 1] || ::File.basename(::File.dirname(::File.dirname(path)))
          tree = parse_html(html, site: site, source: path.to_s)
          { ok: true, path: path.to_s, site: site, tree: tree, metrics: tree_metrics(tree) }
        rescue ::StandardError => e
          { ok: false, path: path.to_s, reason: :parse_failed, because: "#{e.class}: #{e.message}" }
        end

        def parse_all(glob: nil, monorepo_root: nil)
          root = monorepo_root || default_monorepo_root
          pattern = glob || ::File.join(root, "gems", "app-*", "landing", "index.html")
          paths = ::Dir.glob(pattern).sort
          results = paths.map { |p| parse_file(p) }
          ok = results.count { |r| r[:ok] }
          {
            ok: true,
            n: paths.size,
            parsed: ok,
            failed: paths.size - ok,
            trees: results.select { |r| r[:ok] },
            failures: results.reject { |r| r[:ok] },
            component_count_baseline: SalCatalog.kinds.size,
            distinct_kinds_observed: results.select { |r| r[:ok] }.flat_map { |r| collect_kinds(r[:tree]) }.uniq.sort
          }
        rescue ::StandardError => e
          { ok: false, reason: :parse_all_failed, because: "#{e.class}: #{e.message}" }
        end

        def persist!(parse_result, dir:)
          ::FileUtils.mkdir_p(dir)
          written = []
          ::Kernel.Array(parse_result[:trees] || [parse_result]).each do |r|
            next unless r[:ok] && r[:tree]
            site = r[:site] || "unknown"
            path = ::File.join(dir, "#{site}.json")
            payload = {
              site: site,
              source: r[:path],
              parsed_at: ::Time.now.utc.iso8601,
              metrics: r[:metrics],
              tree: r[:tree]
            }
            ::File.write(path, ::JSON.pretty_generate(payload))
            written << path
          end
          { ok: true, n: written.size, paths: written, dir: dir }
        rescue ::StandardError => e
          { ok: false, reason: :persist_failed, because: "#{e.class}: #{e.message}" }
        end

        def parse_html(html, site:, source:)
          tokens = tokenize(html.to_s)
          root = { kind: "surface", value: site.to_s, sal: true,
                   attrs: { role: "surface", source: source }, children: [] }
          stack = [root]
          tokens.each do |tok|
            case tok[:type]
            when :open
              next if SKIP_TAGS.include?(tok[:tag])
              kind = SalCatalog.map_tag(tok[:tag], class_name: tok[:attrs]["class"])
              node = {
                kind: kind,
                value: tok[:attrs]["id"] || tok[:attrs]["aria-label"] || tok[:tag],
                html_tag: tok[:tag],
                sal: SalCatalog.sal?(kind),
                content_role: content_role_for(tok),
                attrs: tok[:attrs],
                children: []
              }
              stack.last[:children] << node
              stack << node unless void?(tok[:tag]) || tok[:self_closing]
            when :close
              next if SKIP_TAGS.include?(tok[:tag])
              # pop until matching tag or surface
              while stack.size > 1
                top = stack.pop
                break if top[:html_tag] == tok[:tag]
              end
            when :text
              text = tok[:text].to_s.gsub(/\s+/, " ").strip
              next if text.empty?
              stack.last[:children] << {
                kind: "text", value: text[0, 200], sal: true, children: []
              }
            end
          end
          annotate_fingerprints!(root)
          root
        end

        def tokenize(html)
          tokens = []
          i = 0
          s = html.to_s
          while i < s.length
            if s[i] == "<"
              if s[i + 1] == "!" || (s[i + 1] == "/" && s[i + 2] == "!")
                # comment / doctype
                j = s.index(">", i) || (s.length - 1)
                i = j + 1
                next
              end
              closing = s[i + 1] == "/"
              j = s.index(">", i) || (s.length - 1)
              raw = s[(i + 1)...j].to_s
              raw = raw[1..] if closing
              self_closing = raw.end_with?("/")
              raw = raw.sub(%r{/\s*\z}, "")
              tag, attrs = parse_tag_open(raw)
              tokens << if closing
                          { type: :close, tag: tag }
                        else
                          { type: :open, tag: tag, attrs: attrs, self_closing: self_closing }
                        end
              i = j + 1
            else
              j = s.index("<", i) || s.length
              text = s[i...j]
              tokens << { type: :text, text: text } unless text.strip.empty?
              i = j
            end
          end
          tokens
        end

        def parse_tag_open(raw)
          parts = raw.strip.split(/\s+/, 2)
          tag = parts[0].to_s.downcase.gsub(/[^a-z0-9]/, "")
          attrs = {}
          if parts[1]
            parts[1].scan(/([:@\w\-]+)\s*=\s*("([^"]*)"|'([^']*)'|(\S+))/).each do |m|
              key = m[0].to_s.downcase
              val = m[2] || m[3] || m[4] || ""
              attrs[key] = val
            end
          end
          [tag, attrs]
        end

        def void?(tag)
          %w[img input br hr meta link area base col embed source track wbr].include?(tag)
        end

        def content_role_for(tok)
          idc = "#{tok[:attrs]["id"]} #{tok[:attrs]["class"]}".downcase
          return "hero" if idc.match?(/hero|banner/)
          return "nav" if tok[:tag] == "nav" || idc.match?(/nav|menu/)
          return "features" if idc.match?(/feature|value-prop/)
          return "cta" if idc.match?(/cta|get-started|signup/)
          return "footer" if tok[:tag] == "footer"
          return "header" if tok[:tag] == "header"

          tok[:tag]
        end

        def annotate_fingerprints!(node)
          kids = ::Kernel.Array(node[:children])
          kids.each { |c| annotate_fingerprints!(c) }
          label = [node[:kind], node[:content_role], kids.map { |c| c[:fingerprint] }.join(",")].join("|")
          node[:fingerprint] = ::Digest::SHA1.hexdigest(label)[0, 16]
          node[:size] = 1 + kids.sum { |c| c[:size].to_i }
          node
        end

        def tree_metrics(tree)
          kinds = collect_kinds(tree)
          {
            nodes: tree[:size].to_i,
            distinct_kinds: kinds.uniq.size,
            kinds: kinds.tally,
            sal_typed: count_sal(tree),
            residual_non_sal: count_non_sal(tree)
          }
        end

        def collect_kinds(node, acc = [])
          acc << node[:kind].to_s
          ::Kernel.Array(node[:children]).each { |c| collect_kinds(c, acc) }
          acc
        end

        def count_sal(node)
          n = node[:sal] ? 1 : 0
          n + ::Kernel.Array(node[:children]).sum { |c| count_sal(c) }
        end

        def count_non_sal(node)
          n = node[:sal] ? 0 : 1
          n + ::Kernel.Array(node[:children]).sum { |c| count_non_sal(c) }
        end

        def default_monorepo_root
          # gems/mmg-acia/lib/mmg/acia/component_min -> monorepo root (5 up)
          ::File.expand_path("../../../../..", __dir__)
        end


        # Fix monorepo root: this file is at gems/mmg-acia/lib/mmg/acia/component_min/
      end
    end
  end
end
