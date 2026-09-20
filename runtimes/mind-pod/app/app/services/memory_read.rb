# frozen_string_literal: true

# S4: memory.read. Serving Gold under a hard budget, on BACK, as a PULL.
#
# Input: a ContextFrame plus a real token budget (and an optional cue for
# the memory half). Output: activated meanings/clarifications plus blob
# refs -- never a generation. Generation stays on switch; nothing here
# calls it, and a grep can prove that: this file names no switch client.
#
# Pack order is frame first, then Gold profiles, then Silver facts: the
# frame is the requested context, contracted Gold outranks raw Silver.
# Zero-weight joins are inspectable, never injected; absent pairs are
# unlisted (absent is not zero). The budget truncates the ordered pack
# (at least one item; the truncated flag tells the story).
#
# The memory half runs only when a cue is given: without a selector there
# is nothing to recall. Subjects rank by token overlap (Retrieval depth
# 20, the Assemble default); Gold profiles of matched subjects come
# before their Silver facts. as_of filters world time; by default only
# currently-live facts serve.
#
# Pure Ruby apart from the frame lookup (ActiveRecord): the pack assembly
# over loaded rows is plain data flow.
module MemoryRead
  RETRIEVAL_DEPTH = 20
  MAX_BUDGET_TOKENS = 32_000

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri
    frame budget_tokens cue as_of
  ].freeze

  module_function

  def call(params, graph_client: nil)
    p = stringify(params)
    budget = p["budget_tokens"]
    unless budget.is_a?(Integer) && budget >= 1 && budget <= MAX_BUDGET_TOKENS
      raise refusal("audit_rejected", {
                      "detail" => "memory.read needs budget_tokens 1..#{MAX_BUDGET_TOKENS}, " \
                                  "got #{budget.inspect}; the budget is what makes this a pack"
                    })
    end

    frame = find_frame(p["frame"])
    if frame.nil?
      raise refusal("frame_not_found", {
                      "detail" => "no ContextFrame #{p["frame"].inspect}; a pack is served for a frame, not into the void",
                      "frame" => p["frame"].to_s
                    })
    end

    as_of = p["as_of"].to_s.empty? ? nil : p["as_of"].to_s
    walked, inert = walk_frame(frame)
    memory_items, blob_refs = read_memory(
      graph_client, cue: p["cue"].to_s, as_of: as_of
    )
    injected, tokens, truncated = apply_budget(walked + memory_items, budget)

    {
      "frame" => frame.canonical_id,
      "injected" => injected,
      "inspectable" => inert,
      "blob_refs" => blob_refs,
      "tokens" => tokens,
      "truncated" => truncated,
      "budget_tokens" => budget,
      "as_of" => as_of
    }
  end

  def find_frame(ref)
    return nil if ref.nil? || ref.to_s.empty?

    ContextFrame.find_by(canonical_id: ref.to_s) ||
      (ref.to_s =~ /\A\d+\z/ ? ContextFrame.find_by(id: ref.to_i) : nil)
  end
  private_class_method :find_frame

  # Frame walk: positive joins only, strongest first (the models' own
  # operative scope). Returns [injected-candidates, inert rows].
  def walk_frame(frame)
    injected = []
    inert = []
    frame.context_frame_meaning_weights.order(weight: :desc).includes(:meaning).each do |join|
      meaning = join.meaning
      next if meaning.nil?

      w = join.weight.to_f
      if w > 0
        injected << {
          "kind" => "meaning", "id" => meaning.id, "title" => meaning.title.to_s,
          "excerpt" => meaning.excerpt.to_s, "weight" => w
        }
        meaning.meaning_clarification_weights.order(weight: :desc).includes(:clarification).each do |cjoin|
          cl = cjoin.clarification
          next if cl.nil?

          cw = cjoin.weight.to_f
          row = {
            "kind" => "clarification", "id" => cl.id, "title" => cl.title.to_s,
            "excerpt" => cl.excerpt.to_s, "source" => cl.source.to_s, "weight" => cw
          }
          if cw > 0
            injected << row
          else
            inert << row
          end
        end
      elsif w == 0
        inert << {
          "kind" => "meaning", "id" => meaning.id, "title" => meaning.title.to_s,
          "excerpt" => meaning.excerpt.to_s, "weight" => 0.0
        }
      else
        inert << {
          "kind" => "meaning", "id" => meaning.id, "title" => meaning.title.to_s,
          "excerpt" => meaning.excerpt.to_s, "weight" => w
        }
      end
    end
    [injected, inert]
  end
  private_class_method :walk_frame

  def item_tokens(item)
    case item["kind"]
    when "meaning", "clarification"
      "#{item["title"]} #{item["excerpt"]}".split.size
    when "gold_profile"
      item["text"].to_s.split.size
    when "silver_fact"
      "#{item["predicate"]} #{item["object"]}".split.size
    else
      item["text"].to_s.split.size
    end
  end
  private_class_method :item_tokens

  def apply_budget(ordered, budget)
    out = []
    used = 0
    ordered.each do |item|
      t = item_tokens(item)
      break if !out.empty? && used + t > budget

      out << item
      used += t
    end
    [out, used, out.size < ordered.size]
  end
  private_class_method :apply_budget

  # Memory half: cue-ranked subjects, Gold profiles before Silver facts.
  # Returns [items, blob_refs]. No cue, no recall.
  def read_memory(graph_client, cue:, as_of:)
    return [[], []] if cue.strip.empty?

    client = graph_client || Mmg::Graph::Execute
    labels, facts = load_silver(client)
    live = as_of.nil? ? facts.select { |f| f[:valid_to].nil? } :
      facts.select { |f| f[:valid_from] && f[:valid_from] <= as_of && (f[:valid_to].nil? || as_of < f[:valid_to]) }
    ranked = rank_subjects(labels, live, cue)
    return [[], []] if ranked.empty?

    gold = load_gold(client)
    items = []
    blob_refs = []
    ranked.each do |subject_iri|
      gold.select { |g| g[:subject] == subject_iri }.each do |profile|
        text = profile[:lines].map { |p, o| "#{p} #{o}" }.join("\n")
        items << {
          "kind" => "gold_profile", "subject_iri" => subject_iri,
          "profile_iri" => profile[:profile], "text" => text,
          "triples" => profile[:lines].size
        }
        profile[:episodes].each do |ep|
          blob_refs |= [episode_digest(ep)]
        end
      end
      live.select { |f| f[:subject] == subject_iri }.each do |f|
        items << {
          "kind" => "silver_fact", "subject_iri" => f[:subject],
          "predicate" => f[:predicate], "object" => f[:object],
          "valid_from" => f[:valid_from], "fact" => f[:fact]
        }
        blob_refs |= [episode_digest(f[:source_episode])] unless f[:source_episode].nil?
      end
    end
    [items, blob_refs.compact]
  end
  private_class_method :read_memory

  def episode_digest(episode_iri)
    m = episode_iri.to_s.match(/sha256:[0-9a-f]+\z/)
    m && m[0]
  end
  private_class_method :episode_digest

  def tokenize(text)
    text.to_s.downcase.scan(/[a-z0-9]+/).uniq
  end
  private_class_method :tokenize

  def rank_subjects(labels, facts, cue)
    cue_tokens = tokenize(cue)
    return [] if cue_tokens.empty?

    texts = Hash.new { |h, k| h[k] = [] }
    facts.each do |f|
      texts[f[:subject]] << "#{f[:predicate]} #{f[:object]}"
    end
    labels.each do |l|
      texts[l[:subject]] << l[:surface]
    end
    scored = texts.map do |subject_iri, lines|
      overlap = (tokenize(lines.join(" ")).uniq & cue_tokens).size
      next nil if overlap.zero?

      [subject_iri, overlap]
    end.compact
    scored.sort_by { |subject_iri, overlap| [-overlap, subject_iri] }
          .first(RETRIEVAL_DEPTH).map(&:first)
  end
  private_class_method :rank_subjects

  def load_silver(client)
    lab = client.query(
      "# s4:labels\nSELECT ?s ?o WHERE { GRAPH <#{MemoryConform::SILVER_GRAPH}> { ?s <mm:label> ?o } }"
    )
    unless lab.is_a?(Hash) && lab[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Silver label read failed: #{lab.inspect[0, 200]}",
                      "graph" => MemoryConform::SILVER_GRAPH
                    })
    end
    labels = Array(lab[:rows]).map do |row|
      r = stringify(row)
      { subject: r["s"].to_s, surface: r["o"].to_s }
    end

    all = client.query(
      "# s4:facts\nSELECT ?f ?p ?o WHERE { GRAPH <#{MemoryConform::SILVER_GRAPH}> { ?f ?p ?o } }"
    )
    unless all.is_a?(Hash) && all[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Silver fact read failed: #{all.inspect[0, 200]}",
                      "graph" => MemoryConform::SILVER_GRAPH
                    })
    end
    by_fact = {}
    Array(all[:rows]).each do |row|
      r = stringify(row)
      (by_fact[r["f"]] ||= {})[r["p"]] = r["o"]
    end
    facts = []
    by_fact.each do |fact_iri, cols|
      next if cols["mm:subject"].nil?

      facts << {
        fact: fact_iri, subject: cols["mm:subject"], predicate: cols["mm:predicate"],
        object: cols["mm:object"], valid_from: cols["mm:validFrom"], valid_to: cols["mm:validTo"],
        source_episode: cols["mm:sourceEpisode"]
      }
    end
    [labels, facts]
  end
  private_class_method :load_silver

  # Gold profiles grouped by profile iri, attributed to their mm:subject.
  def load_gold(client)
    res = client.query(
      "# s4:gold\nSELECT ?s ?p ?o WHERE { GRAPH <#{gold_graph_iri}> { ?s ?p ?o } }"
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Gold read failed: #{res.inspect[0, 200]}",
                      "graph" => gold_graph_iri
                    })
    end
    by_profile = {}
    Array(res[:rows]).each do |row|
      r = stringify(row)
      (by_profile[r["s"].to_s] ||= []) << [r["p"].to_s, r["o"].to_s]
    end
    by_profile.map do |profile_iri, lines|
      cols = lines.to_h
      {
        profile: profile_iri, subject: cols["mm:subject"], lines: lines,
        episodes: lines.select { |p, _| p == "mm:sourceEpisode" }.map(&:last).uniq
      }
    end.select { |g| !g[:subject].nil? }
  end
  private_class_method :load_gold

  def gold_graph_iri
    "urn:mm:medallion/memory.promote/gold/1"
  end
  private_class_method :gold_graph_iri

  # Runtime twin for Memory::ReadEffectShape... pull: Memory::ReadPullShape.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    v << { path: "frame", message: "memory.read serves a frame" } if blank?(g["frame"])
    b = g["budget_tokens"]
    unless b.is_a?(Integer) && b >= 1 && b <= MAX_BUDGET_TOKENS
      v << { path: "budget_tokens", message: "budget_tokens is an integer 1..#{MAX_BUDGET_TOKENS}" }
    end
    v << { path: "as_of", message: "as_of must not be blank" } if g.key?("as_of") && blank?(g["as_of"])
    v
  end

  # Runtime twin for Memory::ReadContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a read response carries exactly one pack" } if item.nil?
    if item
      v << { path: "frame", message: "read must report the frame it served" } if blank?(item["frame"])
      v << { path: "injected", message: "read must report the injected pack as a list" } unless item["injected"].is_a?(Array)
      t = item["tokens"]
      v << { path: "tokens", message: "read must report its token count" } unless t.is_a?(Integer) && t >= 0
    end
    v
  end

  def refusal(reason, because)
    RailsOsiLevel8::KnownRefusal.new(reason, because)
  end
  private_class_method :refusal

  def blank?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end
  private_class_method :blank?

  def stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    else obj
    end
  end
  private_class_method :stringify
end
