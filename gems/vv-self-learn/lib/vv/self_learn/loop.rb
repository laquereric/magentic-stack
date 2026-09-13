# frozen_string_literal: true

module Vv
  module SelfLearn
    # GOLD → PROD → Bronze collection → Gold recommendation.
    module Loop
      STAGES = %w[gold prod bronze_collection gold_recommendation].freeze

      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def collect(params)
        p = stringify(params)
        if p["summary"].to_s != "" && p["provenance"].to_s != "inferred"
          return Refusal.build(Refusal::BRONZE_MUTATED,
                               "a summary may be inferred Bronze with a parent; it may not land observed")
        end
        gold = p["gold_digest"].to_s
        unless Refusal.digest?(gold)
          return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED, "collect cites the Gold that served")
        end
        Refusal.ok(
          gold_digest: gold,
          provenance: "observed",
          generation: 0,
          kind: p["kind"].to_s.empty? ? "receipt" : p["kind"].to_s
        )
      end

      def eval(params)
        p = stringify(params)
        if p["llm_judge"].to_s == "true" || p["grader"].to_s == "llm"
          return Refusal.build(Refusal::GRADER_NOT_DETERMINISTIC,
                               Refusal::WHEN[Refusal::GRADER_NOT_DETERMINISTIC])
        end
        n = (p["n"] || p["planned_n"]).to_i
        passes = p["passes"].to_i
        stats = Wilson.interval(passes, n)
        return stats unless stats[:ok]

        gold = p["gold_digest"].to_s
        cand = p["candidate_digest"].to_s
        gold_rate = p.key?("gold_rate") ? p["gold_rate"].to_f : stats[:rate]
        delta = stats[:rate] - gold_rate
        coverage = p["coverage"] || {
          "cases" => Array(p["cases"]),
          "because" => "golden set, not the population"
        }

        recommend = if p["deterministic"].to_s == "true" || p["deterministic"] == true
                      passes == n && n.positive?
                    else
                      false # LLM-family eval never auto-recommends from this gem
                    end

        if recommend && delta.zero? && gold != cand && !cand.empty?
          recommend = false
          because = Refusal::WHEN[Refusal::EQUAL_SCORES_NOT_BETTER]
        else
          because = recommend ? "planned comparison supports a candidate" : "no promote evidence"
        end

        Refusal.ok(
          gold_digest: gold,
          candidate_digest: cand,
          n: stats[:n],
          passes: stats[:passes],
          rate: stats[:rate],
          wilson95: stats[:wilson95],
          delta_rate: delta,
          coverage: coverage,
          recommend: recommend,
          because: because
        )
      end

      def recommend(params)
        report = eval(params)
        return report unless report[:ok]

        report
      end

      def dispatch(name, params = {})
        n = name.to_s
        found = Operations.named(n)
        if found == :v2
          return Refusal.build(Refusal::ORNITH_NOT_V1, "use vv-orinth / plan_ornith.md for #{n}")
        end
        unless found
          return Refusal.build(Refusal::AUDIT_REJECTED, "unknown method #{n}")
        end
        if !found.prod && stringify(params)["role"].to_s == "prod"
          return Refusal.build(Refusal::PROD_WRITE_REFUSED, Refusal::WHEN[Refusal::PROD_WRITE_REFUSED])
        end
        case n
        when "learn.collect" then collect(params)
        when "learn.eval" then eval(params)
        when "learn.recommend" then recommend(params)
        else
          Refusal.build(Refusal::AUDIT_REJECTED, "unwired #{n}")
        end
      end
    end
  end
end
