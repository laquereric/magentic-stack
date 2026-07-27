# frozen_string_literal: true

require "json"

module Mmg
  module Acia
    module ComponentMin
      # Frequent-subtree mining across persisted trees (brief 2).
      # Exact fingerprint frequency + coverage; optional RDF tagging.
      module Miner
        module_function

        GRAPH_IRI = "urn:mm:graph:acia_component_min"

        # trees: array of { site:, tree: } or parse_all result
        def mine(trees, min_support: 3, min_size: 3)
          rows = normalize_trees(trees)
          index = Hash.new { |h, k| h[k] = { count: 0, sites: [], kind: nil, size: 0, sample: nil } }

          rows.each do |row|
            walk(row[:tree]) do |node|
              next if node[:size].to_i < min_size
              fp = node[:fingerprint]
              next if fp.to_s.empty?

              rec = index[fp]
              rec[:count] += 1
              rec[:sites] << row[:site] unless rec[:sites].include?(row[:site])
              rec[:kind] ||= node[:kind]
              rec[:size] = node[:size].to_i
              rec[:sample] ||= node_skeleton(node)
            end
          end

          candidates = index.map do |fp, rec|
            {
              fingerprint: fp,
              frequency: rec[:count],
              page_support: rec[:sites].size,
              coverage: (rec[:sites].size.to_f / [rows.size, 1].max).round(4),
              kind: rec[:kind],
              size: rec[:size],
              sites: rec[:sites],
              skeleton: rec[:sample]
            }
          end
          candidates.select! { |c| c[:page_support] >= min_support }
          candidates.sort_by! { |c| [-c[:page_support], -c[:frequency], -c[:size]] }

          graph = tag_graph!(candidates)
          {
            ok: true,
            n_pages: rows.size,
            n_candidates: candidates.size,
            min_support: min_support,
            min_size: min_size,
            candidates: candidates,
            graph: graph,
            component_count_baseline: SalCatalog.kinds.size
          }
        rescue ::StandardError => e
          { ok: false, reason: :mine_failed, because: "#{e.class}: #{e.message}" }
        end

        def mine_from_dir(dir, **opts)
          trees = ::Dir.glob(::File.join(dir, "*.json")).map do |p|
            data = ::JSON.parse(::File.read(p))
            { site: data["site"], tree: symbolize(data["tree"]) }
          end
          mine(trees, **opts)
        end

        def walk(node, &blk)
          return if node.nil?

          yield node
          ::Kernel.Array(node[:children] || node["children"]).each { |c| walk(symbolize(c), &blk) }
        end

        def node_skeleton(node)
          {
            kind: node[:kind],
            content_role: node[:content_role],
            sal: node[:sal],
            children: ::Kernel.Array(node[:children]).map { |c|
              { kind: c[:kind], content_role: c[:content_role] }
            }
          }
        end

        def tag_graph!(candidates)
          return { ok: false, reason: :store_absent } unless defined?(::Vv::Graph::Sparql) || defined?(::Vv::Graph::Store)

          triples = []
          candidates.first(50).each do |c|
            iri = "urn:mm:acia:pattern:#{c[:fingerprint]}"
            triples << "<#{iri}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:mm:vocab/acia#SharedPattern> ."
            triples << "<#{iri}> <urn:mm:vocab/acia#fingerprint> #{c[:fingerprint].inspect} ."
            triples << "<#{iri}> <urn:mm:vocab/acia#pageSupport> "#{c[:page_support]}"^^<http://www.w3.org/2001/XMLSchema#integer> ."
            triples << "<#{iri}> <urn:mm:vocab/acia#kind> #{c[:kind].to_s.inspect} ."
          end
          body = triples.join("\n")
          if defined?(::Vv::Graph::Sparql)
            res = ::Vv::Graph::Sparql.execute("INSERT DATA { #{body} }", graph: GRAPH_IRI) rescue { ok: false }
            return res.is_a?(::Hash) ? res.merge(n: triples.size) : { ok: !!res, n: triples.size }
          end
          { ok: true, n: triples.size, deferred: true, note: "SPARQL absent; triples prepared" }
        rescue ::StandardError => e
          { ok: false, reason: :tag_failed, because: "#{e.class}: #{e.message}" }
        end

        def normalize_trees(trees)
          if trees.is_a?(::Hash) && trees[:trees]
            trees[:trees].map { |r| { site: r[:site], tree: symbolize(r[:tree]) } }
          else
            ::Kernel.Array(trees).map { |r|
              r = r.transform_keys(&:to_sym) if r.is_a?(::Hash)
              { site: r[:site], tree: symbolize(r[:tree]) }
            }
          end
        end

        def symbolize(obj)
          case obj
          when ::Hash
            obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize(v) }
          when ::Array
            obj.map { |v| symbolize(v) }
          else
            obj
          end
        end
      end
    end
  end
end
