# frozen_string_literal: true

require "digest"

# S3: memory.promote. Silver -> Gold persona profile, on BACK, explicitly
# invoked (there is no BACKJOB auto-promote in this slice: promotion
# needs a subject, and no journal linkage carries one -- see below).
#
# S3 ships ONE contracted product: the single-principal persona profile
# (roles + labels, current). Failure-lessons as Procedural Gold is the
# more valuable, larger second product and stays an open question.
#
# The engine does the promotion, BACK composes it: this service reads the
# subject's current Silver, builds Gold triples, gates them through
# mmg_shacl_v1 ("gold:v1"), and hands the batch to an ARMED
# Mmg::Medallion::Curator, which enforces the M6 model+contract gate, the
# M3 evidence check, and writes the gold graph (M1). BACK never writes
# Gold around the engine.
#
# Idempotency is structural: RDF graphs are sets, so re-promoting writes
# the same triples twice and stores them once. No skip logic needed.
#
# Pure Ruby: no ActiveRecord. graph_client injects for tests (default
# Mmg::Graph::Execute).
module MemoryPromote
  PERSONA_MODEL = {
    "iri" => "urn:mm:model/persona-profile", "version" => "1",
    "status" => "governed", "owner" => "steward",
    "definition" => "Single-principal persona: durable roles and labels resolved across sessions."
  }.freeze

  PERSONA_CONTRACT = {
    "iri" => "urn:mm:contract/persona-profile", "version" => "1",
    "semantic_model_iri" => "urn:mm:model/persona-profile",
    "shape_set_iri" => "gold:v1", "freshness_sla" => "P7D"
  }.freeze

  GOLD_FLOW = "memory.promote"

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri subject_iri
  ].freeze

  module_function

  def call(params, graph_client: nil)
    p = stringify(params)
    opid = p["operationId"].to_s
    if opid.empty?
      raise refusal("operation_id_required", { "detail" => "memory.promote names its effect first" })
    end
    subject = p["subject_iri"].to_s
    if subject.empty?
      raise refusal("audit_rejected", { "detail" => "memory.promote needs subject_iri: promotion promotes someone" })
    end

    result = promote_subject(subject_iri: subject, graph_client: graph_client)
    result.merge("subject_iri" => subject)
  end

  def promote_subject(subject_iri:, graph_client: nil)
    client = graph_client || Mmg::Graph::Execute
    labels, facts = load_silver(client)
    live = facts.select { |f| f[:subject] == subject_iri && f[:valid_to].nil? }
    surfaces = labels.select { |l| l[:subject] == subject_iri }.map { |l| l[:surface] }.uniq
    if live.empty? && surfaces.empty?
      raise refusal("audit_rejected", {
                      "detail" => "no current Silver for #{subject_iri}: promotion needs something to promote",
                      "subject_iri" => subject_iri
                    })
    end

    profile_iri = "urn:mm:gold:persona:#{subject_iri.sub(/\Aurn:mm:entity:/, '')}"
    as_of = live.map { |f| f[:valid_from] }.compact.max
    episodes = live.map { |f| f[:source_episode] }.compact.uniq
    lines = []
    lines << "<#{profile_iri}> <mm:subject> <#{subject_iri}> ."
    lines << "<#{profile_iri}> <mm:model> <#{PERSONA_MODEL['iri']}> ."
    lines << "<#{profile_iri}> <mm:contract> <#{PERSONA_CONTRACT['iri']}> ."
    lines << "<#{profile_iri}> <mm:asOf> \"#{as_of}\" ." unless as_of.nil?
    live.each do |f|
      lines << "<#{profile_iri}> <#{f[:predicate]}> \"#{nt_escape(f[:object])}\" ."
    end
    surfaces.each do |surface|
      lines << "<#{profile_iri}> <mm:label> \"#{nt_escape(surface)}\" ."
    end
    episodes.each do |ep|
      lines << "<#{profile_iri}> <mm:sourceEpisode> <#{ep}> ."
    end

    gate = gold_shape_set.validate(lines)
    unless gate[:ok]
      raise refusal("shacl_failed", {
                      "detail" => "#{gate[:violations].size} SHACL violation(s): " \
                                  "#{gate[:violations].first(3).join('; ')}",
                      "violations" => gate[:violations]
                    })
    end

    model = Mmg::Medallion::SemanticModel.new(
      iri: PERSONA_MODEL["iri"], version: PERSONA_MODEL["version"],
      status: PERSONA_MODEL["status"], owner: PERSONA_MODEL["owner"],
      definition: PERSONA_MODEL["definition"]
    )
    contract = Mmg::Medallion::Contract.new(
      iri: PERSONA_CONTRACT["iri"], version: PERSONA_CONTRACT["version"],
      semantic_model_iri: PERSONA_CONTRACT["semantic_model_iri"],
      shape_set_iri: PERSONA_CONTRACT["shape_set_iri"],
      freshness_sla: PERSONA_CONTRACT["freshness_sla"]
    )
    flow = Mmg::Medallion::Flow.new(
      GOLD_FLOW, source_graphs: [MemoryConform::SILVER_GRAPH],
      target_tier: "gold", shape_set: "gold:v1", version: "1"
    )
    promoted = Mmg::Medallion::Curator.promote(
      flow: flow,
      silver: {
        "tier" => "silver", "triples" => lines, "revision" => "1",
        "shacl_report" => gate, "cas_digest" => "sha256:#{Digest::SHA256.hexdigest(lines.to_s)}"
      },
      semantic_model: model, contract: contract,
      dry_run: false, graph_sink: client
    )
    unless promoted[:ok]
      raise refusal(promoted[:reason].to_s, {
                      "detail" => promoted[:because].to_s,
                      "subject_iri" => subject_iri
                    })
    end

    {
      "profile_iri" => profile_iri,
      "subject_iri" => subject_iri,
      "gold_graph" => promoted[:gold]["target_graph"],
      "model_iri" => PERSONA_MODEL["iri"],
      "contract_iri" => PERSONA_CONTRACT["iri"],
      "triples_written" => lines.size,
      "shacl_engine" => gate[:engine]
    }
  end

  # Silver reads. Same two query shapes as conform (labels, facts), own
  # markers; fact rows carry sourceEpisode for the profile's provenance.
  def load_silver(client)
    lab = client.query(
      "# s3:labels\nSELECT ?s ?o WHERE { GRAPH <#{MemoryConform::SILVER_GRAPH}> { ?s <mm:label> ?o } }"
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
      "# s3:facts\nSELECT ?f ?p ?o WHERE { GRAPH <#{MemoryConform::SILVER_GRAPH}> { ?f ?p ?o } }"
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

  def gold_shape_set
    Mmg::Medallion::ShapeSet.register(
      "gold:v1",
      allow_predicates: %w[mm:subject mm:model mm:contract mm:asOf mm:role mm:label mm:sourceEpisode],
      required_predicates: ["mm:subject"]
    )
  end
  private_class_method :gold_shape_set

  # Runtime twin for Memory::PromoteEffectShape.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    v << { path: "subject_iri", message: "memory.promote needs subject_iri" } if blank?(g["subject_iri"])
    v
  end

  # Runtime twin for Memory::PromoteContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a promote response carries exactly one profile" } if item.nil?
    if item
      v << { path: "profile_iri", message: "promote must report the profile it wrote" } if blank?(item["profile_iri"])
      v << { path: "gold_graph", message: "promote must report the graph it wrote" } if blank?(item["gold_graph"])
      v << { path: "subject_iri", message: "promote must report whose profile it wrote" } if blank?(item["subject_iri"])
      tw = item["triples_written"]
      v << { path: "triples_written", message: "promote must report its triple count" } unless tw.is_a?(Integer) && tw >= 0
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
