# frozen_string_literal: true

module Mmg
  module Acia
    module ComponentMin
      # Minimize component vocabulary starting from SAL-17 (brief 3).
      # Merge high-support mined patterns into generalized kinds; measure each round.
      module Minimizer
        module_function

        # mine_result from Miner.mine; max_rounds default 5
        def minimize(mine_result, max_rounds: 5, min_support: 3)
          base = SalCatalog.kinds.dup
          vocab = base.map { |k| { name: k, source: :sal17, support: nil } }
          ledger = []
          candidates = ::Kernel.Array(mine_result[:candidates] || mine_result["candidates"])
          n_pages = (mine_result[:n_pages] || mine_result["n_pages"] || 1).to_i

          metrics0 = measure(vocab, candidates, n_pages)
          ledger << { round: 0, action: :baseline, metrics: metrics0 }

          round = 0
          candidates.each do |cand|
            break if round >= max_rounds
            next if cand[:page_support].to_i < min_support
            next if cand[:size].to_i < 4

            # Propose a generalized organism name from kind + content skeleton
            name = propose_name(cand)
            next if vocab.any? { |v| v[:name] == name }

            # Accept if coverage high enough — MDL proxy: support * size > threshold
            score = cand[:page_support].to_i * Math.log2([cand[:size].to_i, 2].max)
            next if score < 8.0

            # Merge: add organism; do NOT remove SAL atoms (keep baseline)
            before = measure(vocab, candidates, n_pages)
            vocab << { name: name, source: :mined, support: cand[:page_support],
                       fingerprint: cand[:fingerprint], skeleton: cand[:skeleton] }
            after = measure(vocab, candidates, n_pages)

            # Prefer reuse-ratio increase; allow K to grow only if reuse_ratio rises
            if after[:reuse_ratio] >= before[:reuse_ratio]
              round += 1
              ledger << {
                round: round,
                action: :accept_merge,
                name: name,
                fingerprint: cand[:fingerprint],
                score: score.round(3),
                metrics: after
              }
            else
              vocab.pop
              ledger << {
                round: round,
                action: :reject_merge,
                name: name,
                reason: :reuse_ratio_did_not_improve,
                metrics: before
              }
            end
          end

          final = measure(vocab, candidates, n_pages)
          {
            ok: true,
            rounds: round,
            vocabulary: vocab,
            component_count: vocab.size,
            sal17_count: base.size,
            mined_added: vocab.count { |v| v[:source] == :mined },
            metrics: final,
            ledger: ledger,
            delta_k: vocab.size - base.size
          }
        rescue ::StandardError => e
          { ok: false, reason: :minimize_failed, because: "#{e.class}: #{e.message}" }
        end

        def measure(vocab, candidates, n_pages)
          k = vocab.size
          # reuse: mean page_support of mined+sal covered patterns / n_pages
          supports = candidates.map { |c| c[:page_support].to_i }
          avg_support = supports.empty? ? 0.0 : supports.sum.to_f / supports.size
          covered_pages = candidates.map { |c| c[:page_support].to_i }.max || 0
          reuse_ratio = n_pages.positive? ? (avg_support / n_pages).round(4) : 0.0
          {
            component_count: k,
            candidate_patterns: candidates.size,
            avg_pattern_page_support: avg_support.round(3),
            max_pattern_page_support: covered_pages,
            reuse_ratio: reuse_ratio,
            n_pages: n_pages
          }
        end

        def propose_name(cand)
          kind = cand[:kind].to_s
          role = cand.dig(:skeleton, :content_role) || cand.dig(:skeleton, "content_role") || kind
          base = "org_#{role}_#{kind}".downcase.gsub(/[^a-z0-9_]+/, "_")
          "#{base}_#{cand[:fingerprint].to_s[0, 6]}"
        end
      end
    end
  end
end
