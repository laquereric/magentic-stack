# frozen_string_literal: true

# memory.lookup: named stored queries over Silver and Gold, on BACK as a
# PULL. The caller names a QUERY, never SPARQL: caller-supplied query
# strings arrive with S6's PySparqlFun, not before. Each query is a fixed
# template with bound parameters; an unknown name is refused outright.
#
# Catalog (as data, enforced below):
#   role_at        subject + predicate (+ date) -> object then believed
#   entity_facts   subject -> its live Silver facts
#   episode_facts  episode -> facts sourced from it
#   profile_for    subject -> its Gold profile triples
#
# Pure Ruby: graph_client injects for tests (default Mmg::Graph::Execute).
module MemoryLookup
  QUERIES = %w[role_at entity_facts episode_facts profile_for].freeze

  SILVER_GRAPH = "urn:mm:medallion/memory.conform/silver/1"
  GOLD_GRAPH = "urn:mm:medallion/memory.promote/gold/1"

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri
    name subject_iri episode_iri predicate date
  ].freeze

  module_function

  def call(params, graph_client: nil)
    p = stringify(params)
    name = p["name"].to_s
    unless QUERIES.include?(name)
      raise refusal("audit_rejected", {
                      "detail" => "unknown lookup #{name.inspect}: the catalog is #{QUERIES.join(', ')}; " \
                                  "caller-supplied SPARQL arrives with S6, not before",
                      "query" => name
                    })
    end

    client = graph_client || Mmg::Graph::Execute
    rows = send(:"run_#{name}", client, p)
    { "query" => name, "rows" => rows, "count" => rows.size }
  end

  def run_role_at(client, p)
    subject = required(p, "subject_iri")
    predicate = p["predicate"].to_s.empty? ? "mm:role" : p["predicate"].to_s
    date = p["date"].to_s
    res = client.query(
      "# lookup:role_at\nSELECT ?s ?o ?vf ?vt WHERE { GRAPH <#{SILVER_GRAPH}> { " \
      "?f <mm:subject> <#{subject}> . ?f <mm:predicate> <#{predicate}> . " \
      "?f <mm:subject> ?s . ?f <mm:object> ?o . ?f <mm:validFrom> ?vf . " \
      "OPTIONAL { ?f <mm:validTo> ?vt } } }"
    )
    # Ruby-side scoping mirrors the SPARQL: a store that returns extra
    # rows must not widen the answer.
    ok_rows(res, SILVER_GRAPH).select { |r| r["s"] == subject }.select do |r|
      date.empty? ? r["vt"].nil? : r["vf"] && r["vf"] <= date && (r["vt"].nil? || date < r["vt"])
    end.map { |r| { "object" => r["o"], "valid_from" => r["vf"] } }
  end
  private_class_method :run_role_at

  def run_entity_facts(client, p)
    subject = required(p, "subject_iri")
    res = client.query(
      "# lookup:entity_facts\nSELECT ?f ?p ?o WHERE { GRAPH <#{SILVER_GRAPH}> { " \
      "?f <mm:subject> <#{subject}> . ?f ?p ?o } }"
    )
    clean_facts(group_rows(ok_rows(res, SILVER_GRAPH))).select do |f|
      f["subject"] == subject
    end
  end
  private_class_method :run_entity_facts

  def run_episode_facts(client, p)
    episode = required(p, "episode_iri")
    res = client.query(
      "# lookup:episode_facts\nSELECT ?f ?p ?o WHERE { GRAPH <#{SILVER_GRAPH}> { " \
      "?f <mm:sourceEpisode> <#{episode}> . ?f ?p ?o } }"
    )
    clean_facts(group_rows(ok_rows(res, SILVER_GRAPH))).select do |f|
      f["source_episode"] == episode
    end
  end
  private_class_method :run_episode_facts

  def run_profile_for(client, p)
    subject = required(p, "subject_iri")
    res = client.query(
      "# lookup:profile_for\nSELECT ?s ?p ?o WHERE { GRAPH <#{GOLD_GRAPH}> { " \
      "?s <mm:subject> <#{subject}> . ?s ?p ?o } }"
    )
    profiles = {}
    ok_rows(res, GOLD_GRAPH).each do |r|
      (profiles[r["s"]] ||= []) << r
    end
    out = []
    profiles.each do |profile_iri, rows|
      cols = rows.to_h { |r| [r["p"], r["o"]] }
      next unless cols["mm:subject"] == subject

      rows.each do |r|
        out << { "profile" => profile_iri, "predicate" => r["p"], "object" => r["o"] }
      end
    end
    out
  end
  private_class_method :run_profile_for

  # Full fact rows: the service groups triples itself because the fake
  # (and the seam) returns flat bindings.
  def group_rows(rows)
    by_fact = {}
    rows.each do |r|
      (by_fact[r["f"]] ||= {})[r["p"]] = r["o"]
    end
    by_fact
  end
  private_class_method :group_rows

  def clean_facts(by_fact)
    by_fact.filter_map do |fact_iri, cols|
      next if cols["mm:subject"].nil?

      {
        "fact" => fact_iri, "subject" => cols["mm:subject"],
        "predicate" => cols["mm:predicate"], "object" => cols["mm:object"],
        "valid_from" => cols["mm:validFrom"], "valid_to" => cols["mm:validTo"],
        "source_episode" => cols["mm:sourceEpisode"]
      }
    end
  end
  private_class_method :clean_facts

  def ok_rows(res, graph)
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "lookup read failed: #{res.inspect[0, 200]}",
                      "graph" => graph
                    })
    end
    Array(res[:rows]).map { |row| stringify(row) }
  end
  private_class_method :ok_rows

  def required(p, key)
    value = p[key].to_s
    if value.empty?
      raise refusal("audit_rejected", { "detail" => "lookup needs #{key} for this query" })
    end

    value
  end
  private_class_method :required

  # Runtime twin for Memory::LookupPullShape.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    if blank?(g["name"])
      v << { path: "name", message: "lookup names its query" }
    elsif !QUERIES.include?(g["name"].to_s)
      v << { path: "name", message: "unknown lookup #{g["name"].inspect}: #{QUERIES.join(', ')}" }
    end
    v
  end

  # Runtime twin for Memory::LookupContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a lookup response carries exactly one result" } if item.nil?
    if item
      v << { path: "query", message: "lookup must report the query it ran" } if blank?(item["query"])
      v << { path: "rows", message: "lookup must report rows as a list" } unless item["rows"].is_a?(Array)
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
