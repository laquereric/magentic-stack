# frozen_string_literal: true

# S1: memory.land on BACK. Transcript / trajectory bytes -> blob, episode
# IRI -> Bronze graph. Admission (OperationRequest + journal) is the
# adapter's, not this service's: wrap journals received through completed
# around the handler and replays same-operationId retries without calling
# here twice.
#
# Pure Ruby: no ActiveRecord, no Rails. The gems touched here resolve at
# CALL time (vv-medallion_memory for the provenance envelope, mmg-blob
# for content-addressed bytes, mmg-graph for the Bronze INSERT), so this
# file loads wherever BACK loads it and unit-tests without booting Rails.
#
# Failures raise RailsOsiLevel8::KnownRefusal (never-raise at the wire).
# A domain refusal is raised, not returned: a returned {ok: false} would
# journal a COMPLETED receipt for a failure and poison idempotent retry.
module MemoryLand
  # The Bronze graph for landed episodes. Mmg::Medallion::Layer.graph_iri(
  # flow: "memory.episode", tier: "bronze", revision: "1") renders exactly
  # this; the string is copied, not computed, so S1 takes no engine
  # dependency. S2 (conform) will.
  BRONZE_GRAPH = "urn:mm:medallion/memory.episode/bronze/1"

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri
    bytes content_type name description
    session actor observed_at modality source_system kind
    generation derived_from
  ].freeze

  REQUIRED_KEYS = %w[
    bytes session actor observed_at modality source_system kind
  ].freeze

  KINDS = %w[observed inferred].freeze

  module_function

  def call(params, graph_client: nil, blob: nil)
    p = stringify(params)
    opid = p["operationId"].to_s
    if opid.empty?
      raise refusal("operation_id_required", { "detail" => "memory.land names its effect first" })
    end

    env = provenance_envelope(p)
    stored = blob_put(blob, p, env, opid)
    episode_iri = "urn:mm:episode:#{stored[:digest]}"
    graph_write(graph_client, bronze_lines(
      episode_iri: episode_iri, digest: stored[:digest],
      operation_id: opid, provenance: env
    ))

    {
      "episode_iri" => episode_iri,
      "digest" => stored[:digest],
      "stored" => stored[:stored],
      "journal_ref" => opid,
      "graph" => BRONZE_GRAPH
    }
  end

  # Runtime twin for Memory::LandEffectShape: closed shape plus the
  # required set plus the kind vocabulary. Returns violations (empty =
  # conforms), the same contract the grounding case branches return.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    REQUIRED_KEYS.each do |k|
      v << { path: k, message: "memory.land needs #{k}" } if blank?(g[k])
    end
    unless blank?(g["kind"]) || KINDS.include?(g["kind"].to_s)
      v << { path: "kind", message: "kind is observed or inferred, got #{g["kind"].inspect}" }
    end
    v
  end

  # Runtime twin for Memory::LandContextShape: exactly one episode item
  # reporting the iri BACK minted and the digest it filed.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a land response carries exactly one episode" } if item.nil?
    if item
      v << { path: "episode_iri", message: "land must report the episode iri it minted" } if blank?(item["episode_iri"])
      v << { path: "digest", message: "land must report the digest it filed" } if blank?(item["digest"])
    end
    v
  end

  def provenance_envelope(p)
    missing = %w[session actor observed_at modality source_system kind].reject { |k| !blank?(p[k]) }
    unless missing.empty?
      raise refusal("audit_rejected", {
                      "detail" => "memory.land provenance is missing #{missing.join(', ')}; " \
                                  "an episode that cannot say where it came from cannot be replayed"
                    })
    end

    kwargs = {
      session: p["session"].to_s, actor: p["actor"].to_s,
      observed_at: p["observed_at"].to_s, modality: p["modality"].to_s,
      source_system: p["source_system"].to_s, kind: p["kind"].to_s
    }
    kwargs[:generation] = p["generation"] unless blank?(p["generation"])
    kwargs[:derived_from] = p["derived_from"].to_s unless blank?(p["derived_from"])
    env = Vv::MedallionMemory::Provenance.new(**kwargs)
    if (r = env.refusal)
      raise refusal(r[:reason], { "detail" => r[:because], "provenance" => env.to_h })
    end

    env
  end
  private_class_method :provenance_envelope

  def blob_put(blob, p, env, opid)
    operations = blob || Mmg::Blob::Operations
    res = operations.put(
      "bytes" => p["bytes"],
      "date" => env.observed_at,
      "name" => p["name"].to_s.empty? ? "memory-episode:#{env.session}" : p["name"].to_s,
      "description" => p["description"].to_s.empty? ? "memory.land #{opid}" : p["description"].to_s,
      "content_type" => p["content_type"].to_s.empty? ? "text/plain; charset=utf-8" : p["content_type"].to_s
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal(res.is_a?(Hash) ? res[:reason].to_s : "blob_write_failed",
                    { "detail" => res.is_a?(Hash) ? res[:because].to_s : res.inspect[0, 200] })
    end

    res
  end
  private_class_method :blob_put

  def bronze_lines(episode_iri:, digest:, operation_id:, provenance:)
    pairs = [
      ["mm:blob", digest], ["mm:journalRef", operation_id],
      ["mm:session", provenance.session], ["mm:actor", provenance.actor],
      ["mm:observedAt", provenance.observed_at], ["mm:modality", provenance.modality],
      ["mm:sourceSystem", provenance.source_system], ["mm:kind", provenance.kind]
    ]
    pairs << ["mm:generation", provenance.generation.to_s] if provenance.inferred?
    pairs << ["mm:derivedFrom", provenance.derived_from.to_s] if provenance.inferred?
    pairs.map { |pred, val| "<#{episode_iri}> <#{pred}> \"#{nt_escape(val)}\" ." }
  end
  private_class_method :bronze_lines

  def graph_write(graph_client, lines)
    client = graph_client || Mmg::Graph::Execute
    sparql = "INSERT DATA { GRAPH <#{BRONZE_GRAPH}> {\n#{lines.join("\n")}\n} }"
    res = client.update(sparql)
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_write_failed", {
                      "detail" => "Bronze INSERT to #{BRONZE_GRAPH} failed: #{res.inspect[0, 200]}; " \
                                  "the bytes are filed, the graph is not -- retry the same operationId",
                      "graph" => BRONZE_GRAPH
                    })
    end

    res
  end
  private_class_method :graph_write

  def nt_escape(value)
    value.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
  end
  private_class_method :nt_escape

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
