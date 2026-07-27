# frozen_string_literal: true

require "fileutils"
require "json"

module Mmg
  module Acia
    module ComponentMin
      # End-to-end runner for acia_component_minimization briefs 1–4.
      module Pipeline
        module_function

        def run!(monorepo_root: nil, out_dir: nil)
          root = monorepo_root || LandingParser.default_monorepo_root
          out = out_dir || ::File.join(root, "gems", "mmg-acia", "tmp", "component_trees")
          ::FileUtils.mkdir_p(out)

          parsed = LandingParser.parse_all(monorepo_root: root)
          return parsed unless parsed[:ok]

          pers = LandingParser.persist!(parsed, dir: out)
          mined = Miner.mine(parsed, min_support: 3, min_size: 3)
          mini = Minimizer.minimize(mined)

          # Brief 4: set-cover trim + reference rewrite
          page_fps = {}
          ::Kernel.Array(parsed[:trees]).each do |row|
            next unless row[:ok] && row[:tree]

            fps = []
            Miner.walk(row[:tree]) { |n| fps << n[:fingerprint] if n[:fingerprint] }
            page_fps[row[:site]] = fps.uniq
          end

          cover = SetCover.trim(
            mini[:vocabulary],
            page_fps: page_fps,
            candidates: mined[:candidates]
          )
          vocab = cover[:ok] ? cover[:vocabulary] : mini[:vocabulary]

          rewrite_dir = ::File.join(out, "rewrites")
          rew = Rewriter.rewrite_all(parsed, vocabulary: vocab, out_dir: rewrite_dir)

          report = {
            ok: true,
            parsed: { n: parsed[:n], parsed: parsed[:parsed], failed: parsed[:failed] },
            distinct_kinds_observed: parsed[:distinct_kinds_observed],
            persist: pers,
            mining: {
              n_candidates: mined[:n_candidates],
              top: ::Kernel.Array(mined[:candidates]).first(10)
            },
            minimization: {
              component_count: mini[:component_count],
              sal17_count: mini[:sal17_count],
              mined_added: mini[:mined_added],
              metrics: mini[:metrics],
              ledger_rounds: ::Kernel.Array(mini[:ledger]).size
            },
            set_cover: cover,
            rewrite: {
              n_pages: rew[:n_pages],
              sample_site: rew[:sample_site],
              sample_path: rew[:sample_path],
              total_refs: rew[:total_refs],
              total_residual: rew[:total_residual],
              reuse_ratio: rew[:reuse_ratio],
              pages: ::Kernel.Array(rew[:pages]).map { |p|
                p.slice(:site, :ref_count, :residual_nodes, :component_refs)
              }
            },
            metrics_summary: {
              baseline_k: mini[:sal17_count],
              pre_trim_k: mini[:component_count],
              final_covering_k: cover[:ok] ? cover[:final_k] : mini[:component_count],
              mined_removed_as_redundant: cover[:ok] ? cover[:mined_removed] : 0,
              reuse_ratio: rew[:reuse_ratio] || mini.dig(:metrics, :reuse_ratio),
              pages: parsed[:parsed],
              pages_total: parsed[:n],
              pages_failed: parsed[:failed]
            }
          }
          ::File.write(::File.join(out, "_report.json"), ::JSON.pretty_generate(report))
          report
        rescue ::StandardError => e
          { ok: false, reason: :pipeline_failed, because: "#{e.class}: #{e.message}" }
        end
      end
    end
  end
end
