# frozen_string_literal: true

require_relative "store"
require_relative "refusal"

module Vv
  module MedallionMemory
    # Budgeted traversal (Primitive 3, sharpens memory.serve).
    #
    #   Assemble.call(store:, cue:, seeds:, node_budget:, token_ceiling:,
    #                 as_of_tx:, branch_id: nil, vector: nil, weights: {})
    #
    # 1. SEED. Fuse vector hits + keyword hits + pinned seeds with
    #    Reciprocal Rank Fusion (no score calibration). Pinned seeds are a
    #    first-class list, not an override.
    # 2. EXPAND. Dijkstra by cost = hop distance + edge-type weight +
    #    recency + confidence. Budget is DISTINCT SUBJECTS, not tokens.
    #    Expansion order is deterministic, so halving node_budget yields
    #    the priority-prefix of the larger run.
    # 3. DIVERSIFY. Maximal Marginal Relevance over the expanded set, then
    #    serialise in MMR order until token_ceiling (at least one subject;
    #    the truncated flag tells the story).
    # 4. INJECT is Serve's job (activations partition), not this module's.
    #
    # as_of_tx is REQUIRED: a replay that does not name its tx cannot be
    # told apart from current belief (as_of_tx_required). Serve defaults
    # it to the current journal position; direct callers name it.
    #
    # Same seeds + budget + as_of_tx -> byte-identical context: every
    # ordering has an explicit tie-break (score, source, subject_iri),
    # and no wall-clock enters the output.
    #
    # Tokens are whitespace estimates, documented as such: the real
    # tokenizer lives on FRONT, and pretending otherwise would make the
    # ceiling mean different things on the two sides of the wire.
    #
    # Edges run FORWARD (subject -> object) along iri-valued objects.
    # Inverse walks arrive with an arrow directory; they are not smuggled
    # in here.
    module Assemble
      DEFAULT_WEIGHTS = {
        hop: 1.0, edge: 0.5, recency: 0.05, confidence: 0.5,
        rrf_k: 60, retrieval_depth: 20, mmr_lambda: 0.5
      }.freeze

      CONFIDENCE_COSTS = { "L1" => 0.0, "L2" => 0.5, "L3" => 1.0, nil => 0.5 }.freeze

      module_function

      def call(store:, cue: nil, seeds: [], node_budget:, token_ceiling:,
               as_of_tx: nil, branch_id: nil, vector: nil, weights: {})
        if as_of_tx.nil?
          return Refusal.build(
            Refusal::AS_OF_TX_REQUIRED,
            "Assemble.call needs as_of_tx: a replay that does not name its tx cannot be told " \
            "apart from current belief. Ordinary Serve defaults it to the current journal position"
          )
        end
        if node_budget.to_i < 1
          return Refusal.build(Refusal::AUDIT_REJECTED, "node_budget must be >= 1; a pack of nothing packs nothing")
        end

        w = DEFAULT_WEIGHTS.merge(weights.transform_keys(&:to_sym))
        view = visible_facts(store: store, as_of_tx: as_of_tx, branch_id: branch_id)
        texts = subject_texts(view)

        fused = fuse(
          pinned: Array(seeds).map(&:to_s),
          vector: vector_hits(vector: vector, cue: cue, depth: w[:retrieval_depth]),
          keyword: keyword_hits(texts: texts, cue: cue, depth: w[:retrieval_depth]),
          rrf_k: w[:rrf_k]
        )

        expanded = expand(
          fused: fused, view: view, texts: texts,
          node_budget: node_budget.to_i, as_of_tx: as_of_tx, weights: w
        )
        diversified = diversify(expanded: expanded, lambda: w[:mmr_lambda])
        serialised, tokens, truncated = serialise(
          diversified: diversified, token_ceiling: token_ceiling.to_i
        )

        Refusal.ok(
          subjects: serialised, tokens: tokens, truncated: truncated,
          as_of_tx: as_of_tx, node_budget: node_budget.to_i, branch_id: branch_id
        )
      end

      def tokenize(text)
        text.to_s.downcase.scan(/[a-z0-9]+/)
      end

      # Rows this call may see: believed at as_of_tx, on the requested
      # branch. Branch mechanics (Primitive 1) are pending; the rule is
      # already this: main reads see main rows, a branch read sees main
      # plus its own.
      def visible_facts(store:, as_of_tx:, branch_id:)
        store.facts.select do |f|
          next false unless f.believed_on?(as_of_tx)

          branch_id.nil? ? f.branch_id.nil? : (f.branch_id.nil? || f.branch_id.to_s == branch_id.to_s)
        end
      end
      private_class_method :visible_facts

      def subject_texts(view)
        texts = Hash.new { |h, k| h[k] = [] }
        view.each do |f|
          texts[f.subject_iri] << "#{f.predicate} #{f.object_value}"
          texts[f.subject_iri] |= []
        end
        texts.transform_values { |lines| lines.join("\n") }
      end
      private_class_method :subject_texts

      def vector_hits(vector:, cue:, depth:)
        return [] if vector.nil? || cue.to_s.strip.empty?

        vector.search(cue, depth).keys.map(&:to_s)
      end
      private_class_method :vector_hits

      def keyword_hits(texts:, cue:, depth:)
        cue_tokens = tokenize(cue).uniq
        return [] if cue_tokens.empty?

        scored = texts.map do |subject_iri, text|
          overlap = (tokenize(text).uniq & cue_tokens).size
          next nil if overlap.zero?

          [subject_iri, overlap]
        end.compact
        scored.sort_by { |subject_iri, overlap| [-overlap, subject_iri] }
              .first(depth).map(&:first)
      end
      private_class_method :keyword_hits

      # RRF over three lists. Tie-breaks: fused score, then source
      # (pinned < vector < keyword), then subject_iri. All explicit, so
      # the fused order is a pure function of the inputs.
      def fuse(pinned:, vector:, keyword:, rrf_k:)
        scores = Hash.new(0.0)
        best_source = {}
        { 0 => pinned, 1 => vector, 2 => keyword }.each do |source, list|
          list.each_with_index do |subject_iri, rank|
            scores[subject_iri] += 1.0 / (rrf_k + rank)
            best = best_source[subject_iri]
            best_source[subject_iri] = source if best.nil? || source < best
          end
        end
        scores.sort_by { |subject_iri, score| [-score, best_source[subject_iri], subject_iri] }.to_h
      end
      private_class_method :fuse

      def iri_like?(value) = value.to_s.start_with?("urn:")

      def edge_cost(fact:, depth:, as_of_tx:, weights:)
        edge_w = weights[:edge_weights].is_a?(Hash) ?
          (weights[:edge_weights][fact.predicate] || 1.0) : 1.0
        conf = CONFIDENCE_COSTS.fetch(
          fact.confidence,
          weights[:confidence_costs].is_a?(Hash) ? weights[:confidence_costs][fact.confidence] : 0.5
        )
        depth * weights[:hop] + edge_w * weights[:edge] +
          (as_of_tx - fact.tx_from) * weights[:recency] + conf * weights[:confidence]
      end
      private_class_method :edge_cost

      # Dijkstra from fused seeds. Pop order is prefix-stable: stopping at
      # half the budget yields the priority-prefix of the full run, which
      # is what the budget-halving spec asserts.
      def expand(fused:, view:, texts:, node_budget:, as_of_tx:, weights:)
        out_edges = Hash.new { |h, k| h[k] = [] }
        view.each do |f|
          out_edges[f.subject_iri] << f if iri_like?(f.object_value)
        end

        dist = {}
        fused.each { |subject_iri, score| dist[subject_iri] = 1.0 / (1.0 + score) }
        queue = dist.map { |subject_iri, d| [d, subject_iri] }
        ordered = []
        seen = {}

        until queue.empty? || ordered.size >= node_budget
          queue.sort_by! { |d, s| [d, s] }
          d, u = queue.shift
          next if seen[u]

          seen[u] = true
          ordered << {
            subject_iri: u, cost: d.round(6),
            text: texts[u].to_s, priority: ordered.size
          }

          out_edges[u].each do |f|
            v = f.object_value.to_s
            nd = d + edge_cost(fact: f, depth: 1, as_of_tx: as_of_tx, weights: weights)
            queue << [nd, v] if dist[v].nil? || nd < dist[v] - 1e-12
            dist[v] = nd if dist[v].nil? || nd < dist[v]
          end
        end
        ordered
      end
      private_class_method :expand

      def jaccard(a_tokens, b_tokens)
        a, b = a_tokens.uniq, b_tokens.uniq
        return 0.0 if a.empty? || b.empty?

        (a & b).size.to_f / (a | b).size
      end
      private_class_method :jaccard

      # Greedy MMR: relevance is seed relevance (RRF-derived start cost
      # inverted back is overkill; rank order carries it), novelty is
      # Jaccard distance to the already-picked. Reorders, never drops:
      # the set is the expanded set, so budget-prefix stability survives
      # in priority space (each subject keeps its expansion priority).
      def diversify(expanded:, lambda:)
        remaining = expanded.map(&:dup)
        picked = []
        until remaining.empty?
          nxt = remaining.map do |cand|
            rel = 1.0 / (1.0 + cand[:priority])
            novelty = picked.empty? ? 0.0 :
              picked.map { |s| jaccard(tokenize(cand[:text]), tokenize(s[:text])) }.max
            [lambda * rel - (1.0 - lambda) * novelty, cand[:priority], cand]
          end.sort_by { |score, priority, _| [-score, priority] }.first[2]
          picked << nxt
          remaining.delete(nxt)
        end
        picked
      end
      private_class_method :diversify

      def subject_tokens(subject) = subject[:text].to_s.split.size

      def serialise(diversified:, token_ceiling:)
        out = []
        used = 0
        diversified.each do |s|
          t = subject_tokens(s)
          break if !out.empty? && used + t > token_ceiling

          out << s
          used += t
        end
        [out, used, out.size < diversified.size]
      end
      private_class_method :serialise
    end
  end
end
