# frozen_string_literal: true

require "time"

# S5: memory.forget. Tombstone plus cascade, on BACK, explicitly invoked
# (a steward's deletion request, e.g. GDPR -- there is no BACKJOB poll
# for forgetting).
#
# Order is load-bearing:
#   1. read the episode's Silver facts and subjects,
#   2. judge retention evidence through the ENGINE cascade (M8 clock:
#      Bronze forgets need a retention basis and a decider; the engine
#      refusal stops the walk before anything is touched),
#   3. DELETE the Silver fact triples and the Gold profiles sourced from
#      the episode (graph sets make reruns converge),
#   4. INSERT the Bronze tombstone (episode, time, basis, operation).
#
# After forget, memory.read does not serve the fact (its triples are
# gone); Bronze replay still shows the episode plus the tombstone. The
# blob is RETAINED: vv-blob deletes content for every holder of a digest,
# so dropping bytes is a legal-review flow, not a parameter. Platinum
# holds nothing to drop (there is no distilled adapter), which is exactly
# why distill stays blocked.
#
# Pure Ruby apart from no store at all: the graphs are the store.
module MemoryForget
  # Graph iris are copied literals, not cross-service references, so each
  # service file loads standalone (S1 precedent). Sources of truth:
  # MemoryLand::BRONZE_GRAPH, MemoryConform::SILVER_GRAPH.
  BRONZE_GRAPH = "urn:mm:medallion/memory.episode/bronze/1"
  SILVER_GRAPH = "urn:mm:medallion/memory.conform/silver/1"
  GOLD_GRAPH = "urn:mm:medallion/memory.promote/gold/1"

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri
    episode_iri retention_basis decided_by
  ].freeze

  module_function

  def call(params, graph_client: nil)
    p = stringify(params)
    opid = p["operationId"].to_s
    if opid.empty?
      raise refusal("operation_id_required", { "detail" => "memory.forget names its effect first" })
    end
    episode_iri = p["episode_iri"].to_s
    if episode_iri.empty?
      raise refusal("audit_rejected", { "detail" => "memory.forget needs episode_iri: forgetting forgets an episode" })
    end

    result = forget_episode(
      episode_iri: episode_iri,
      retention_basis: p["retention_basis"].to_s,
      decided_by: p["decided_by"].to_s,
      operation_id: opid,
      graph_client: graph_client
    )
    result
  end

  def forget_episode(episode_iri:, retention_basis:, decided_by:, operation_id:, graph_client: nil)
    client = graph_client || Mmg::Graph::Execute
    facts = silver_facts_for(client, episode_iri)
    if facts.empty? && !bronze_episode?(client, episode_iri)
      raise refusal("episode_not_landed", {
                      "detail" => "no Bronze episode #{episode_iri} and no Silver from it; nothing to forget",
                      "episode_iri" => episode_iri
                    })
    end
    subjects = facts.map { |f| f[:subject] }.compact.uniq
    profiles = gold_profiles_for(client, episode_iri)

    # The M8/M9 gate: evidence judged BEFORE anything is touched, and the
    # engine records the tombstone walk alongside the graphs. An empty
    # walk still judges evidence (a rerun converges, but never on bogus
    # basis).
    if subjects.empty?
      gate = Mmg::Medallion::Decay.evidence_refusal(
        tier: "bronze",
        evidence: { retention_basis: retention_basis, decided_by: decided_by }
      )
      unless gate.nil?
        raise refusal(gate[:reason].to_s, {
                        "detail" => gate[:because].to_s,
                        "episode_iri" => episode_iri
                      })
      end
    else
      judged = Mmg::Medallion.cascade(
        iris: subjects, kind: :forget,
        evidence: { retention_basis: retention_basis, decided_by: decided_by }
      )
      unless judged[:ok]
        raise refusal(judged[:reason].to_s, {
                        "detail" => judged[:because].to_s,
                        "episode_iri" => episode_iri
                      })
      end
    end

    removed_facts = 0
    facts.map { |f| f[:fact] }.uniq.each do |fact_iri|
      drop = client.update(
        "# s5:drop\nDELETE WHERE { GRAPH <#{SILVER_GRAPH}> { <#{fact_iri}> ?p ?o } }"
      )
      unless drop.is_a?(Hash) && drop[:ok]
        raise refusal("graph_write_failed", {
                        "detail" => "Silver delete of #{fact_iri} failed: #{drop.inspect[0, 200]}",
                        "graph" => SILVER_GRAPH
                      })
      end
      removed_facts += 1
    end

    removed_profiles = 0
    profiles.each do |profile_iri|
      drop = client.update(
        "# s5:drop\nDELETE WHERE { GRAPH <#{GOLD_GRAPH}> { <#{profile_iri}> ?p ?o } }"
      )
      unless drop.is_a?(Hash) && drop[:ok]
        raise refusal("graph_write_failed", {
                        "detail" => "Gold delete of #{profile_iri} failed: #{drop.inspect[0, 200]}",
                        "graph" => GOLD_GRAPH
                      })
      end
      removed_profiles += 1
    end

    now = Time.now.utc.iso8601
    tombstone = [
      "<#{episode_iri}> <mm:tombstonedAt> \"#{now}\" .",
      "<#{episode_iri}> <mm:retentionBasis> \"#{nt_escape(retention_basis)}\" .",
      "<#{episode_iri}> <mm:forgetOperation> \"#{nt_escape(operation_id)}\" ."
    ]
    # INSERT DATA is idempotent on graph sets: a retry re-adds the same
    # three triples and converges.
    sealed = client.update(
      "INSERT DATA { GRAPH <#{BRONZE_GRAPH}> {\n#{tombstone.join("\n")}\n} }"
    )
    unless sealed.is_a?(Hash) && sealed[:ok]
      raise refusal("graph_write_failed", {
                      "detail" => "Bronze tombstone for #{episode_iri} failed: #{sealed.inspect[0, 200]}",
                      "graph" => BRONZE_GRAPH
                    })
    end

    {
      "episode_iri" => episode_iri,
      "tombstoned" => true,
      "tombstoned_at" => now,
      "subjects" => subjects,
      "silver_facts_removed" => removed_facts,
      "gold_profiles_removed" => removed_profiles,
      "bronze_graph" => BRONZE_GRAPH,
      "silver_graph" => SILVER_GRAPH,
      "gold_graph" => GOLD_GRAPH
    }
  end

  def silver_facts_for(client, episode_iri)
    res = client.query(
      "# s5:silver\nSELECT ?f ?p ?o WHERE { GRAPH <#{SILVER_GRAPH}> { ?f <mm:sourceEpisode> <#{episode_iri}> . ?f ?p ?o } }"
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Silver read for #{episode_iri} failed: #{res.inspect[0, 200]}",
                      "graph" => SILVER_GRAPH
                    })
    end
    by_fact = {}
    Array(res[:rows]).each do |row|
      r = stringify(row)
      (by_fact[r["f"]] ||= {})[r["p"]] = r["o"]
    end
    by_fact.map do |fact_iri, cols|
      { fact: fact_iri, subject: cols["mm:subject"] }
    end.select { |f| !f[:subject].nil? }
  end
  private_class_method :silver_facts_for

  def gold_profiles_for(client, episode_iri)
    res = client.query(
      "# s5:gold\nSELECT ?s WHERE { GRAPH <#{GOLD_GRAPH}> { ?s <mm:sourceEpisode> <#{episode_iri}> } }"
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Gold read for #{episode_iri} failed: #{res.inspect[0, 200]}",
                      "graph" => GOLD_GRAPH
                    })
    end
    Array(res[:rows]).map { |row| stringify(row)["s"].to_s }.uniq
  end
  private_class_method :gold_profiles_for

  def bronze_episode?(client, episode_iri)
    res = client.query(
      "# s5:bronze\nSELECT ?p WHERE { GRAPH <#{BRONZE_GRAPH}> { <#{episode_iri}> ?p ?o } }"
    )
    res.is_a?(Hash) && res[:ok] && Array(res[:rows]).any?
  end
  private_class_method :bronze_episode?

  # Runtime twin for Memory::ForgetEffectShape.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    v << { path: "episode_iri", message: "forgetting forgets an episode" } if blank?(g["episode_iri"])
    v << { path: "retention_basis", message: "a Bronze forget executes on the legal-retention clock" } if blank?(g["retention_basis"])
    v << { path: "decided_by", message: "a tombstone names who decided it" } if blank?(g["decided_by"])
    v
  end

  # Runtime twin for Memory::ForgetContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a forget response carries exactly one tombstone" } if item.nil?
    if item
      v << { path: "episode_iri", message: "forget must report the episode it tombstoned" } if blank?(item["episode_iri"])
      v << { path: "tombstoned", message: "forget must report tombstoned true" } unless item["tombstoned"] == true
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

  def nt_escape(value)
    value.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
  end
  private_class_method :nt_escape

  def stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    else obj
    end
  end
  private_class_method :stringify
end
