# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module ComponentMin
      # Minimum covering-set trim for the component vocabulary (brief 4).
      #
      # Objective: fewest components that still COVER all pages (each page has
      # every non-residual structure mappable to SAL atoms or a mined organism).
      # SAL-17 atoms are never dropped. Mined organisms are greedily pruned if
      # removing them leaves coverage unchanged.
      module SetCover
        module_function

        # vocabulary: Minimizer vocabulary array
        # page_fps: { site => Set|Array of fingerprints present on that page }
        # candidates: miner candidates (with :fingerprint, :sites)
        def trim(vocabulary, page_fps: nil, candidates: nil)
          vocab = ::Kernel.Array(vocabulary).map { |v| symbolize(v) }
          sal = vocab.select { |v| v[:source].to_s == "sal17" || v[:fingerprint].nil? }
          mined = vocab.select { |v| v[:source].to_s == "mined" && v[:fingerprint] }

          sites = site_list(page_fps, candidates)
          cover_map = build_cover_map(mined, candidates)

          # Full coverage: every site that was covered by any mined organism stays covered
          # OR every site has residual SAL-only coverage (always true for SAL atoms).
          # Page-level covering = site appears in union of retained mined component sites
          # OR we treat SAL atoms as universal cover for atomic nodes.
          # Sites that receive ANY mined-organism coverage must keep it after trim.
          # Sites never hit by organisms are covered by SAL atoms alone.
          needed = covered_sites(mined, cover_map)

          kept = mined.dup
          removed = []
          # Greedy reverse-elimination: try drop lowest support first
          ordered = kept.sort_by { |v| [v[:support].to_i, v[:name].to_s] }
          ordered.each do |comp|
            trial = kept.reject { |c| c[:name] == comp[:name] }
            if covers?(trial, cover_map, needed)
              kept = trial
              removed << comp
            end
          end

          final_vocab = sal + kept
          {
            ok: true,
            original_k: vocab.size,
            final_k: final_vocab.size,
            sal_k: sal.size,
            mined_kept: kept.size,
            mined_removed: removed.size,
            removed: removed.map { |c| { name: c[:name], fingerprint: c[:fingerprint], support: c[:support] } },
            vocabulary: final_vocab,
            covered_sites: covered_sites(kept, cover_map).size,
            target_sites: needed.size,
            minimal_covering: true, # post reverse-elimination
            note: "SAL atoms retained; mined organisms reverse-eliminated when redundant"
          }
        rescue ::StandardError => e
          { ok: false, reason: :set_cover_failed, because: "#{e.class}: #{e.message}" }
        end

        def covers?(mined_subset, cover_map, needed_sites)
          return true if needed_sites.nil? || needed_sites.empty?

          cov = covered_sites(mined_subset, cover_map)
          (needed_sites - cov).empty?
        end

        def covered_sites(mined_subset, cover_map)
          mined_subset.flat_map { |c| cover_map[c[:fingerprint]] || cover_map[c[:name]] || [] }.uniq
        end

        def build_cover_map(mined, candidates)
          map = {}
          by_fp = {}
          ::Kernel.Array(candidates).each do |c|
            c = symbolize(c)
            by_fp[c[:fingerprint]] = ::Kernel.Array(c[:sites]).map(&:to_s)
          end
          mined.each do |v|
            fp = v[:fingerprint]
            map[fp] = by_fp[fp] || []
            map[v[:name]] = map[fp]
          end
          map
        end

        def site_list(page_fps, candidates)
          sites = []
          if page_fps.is_a?(::Hash)
            sites |= page_fps.keys.map(&:to_s)
          end
          ::Kernel.Array(candidates).each do |c|
            sites |= ::Kernel.Array(symbolize(c)[:sites]).map(&:to_s)
          end
          sites.uniq
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
