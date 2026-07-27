# frozen_string_literal: true

require "fileutils"
require "json"

module Mmg
  module Acia
    module ComponentMin
      # End-to-end runner for acia_component_minimization briefs 1–3.
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
            metrics_summary: {
              baseline_k: mini[:sal17_count],
              final_k: mini[:component_count],
              reuse_ratio: mini.dig(:metrics, :reuse_ratio),
              pages: parsed[:n]
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
