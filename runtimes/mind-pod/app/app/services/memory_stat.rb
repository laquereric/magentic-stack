# frozen_string_literal: true

# memory.stat: product health as a PULL. Counts per named graph, the last
# promotion, recent SHACL report ids, and rag collection health -- the
# four things an operator asks before trusting a pack.
#
# Rag health is honest, not operational: Silver has never been embedded
# (no vector writes exist anywhere), so the answer is unindexed with its
# reason, not a Milvus call BACK cannot make. rag_write_undecided still
# refuses the write path; this reports the standing state.
#
# Pure Ruby apart from the journal read (ActiveRecord): counts come from
# SPARQL COUNT, history from the journal. The journal reader injects for
# tests (default reads OperationRequests + receipts).
module MemoryStat
  BRONZE_GRAPH = "urn:mm:medallion/memory.episode/bronze/1"
  SILVER_GRAPH = "urn:mm:medallion/memory.conform/silver/1"
  GOLD_GRAPH = "urn:mm:medallion/memory.promote/gold/1"

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri
  ].freeze

  module_function

  def call(params, graph_client: nil, journal: nil)
    client = graph_client || Mmg::Graph::Execute
    counts = {
      "bronze_triples" => count(client, BRONZE_GRAPH),
      "silver_triples" => count(client, SILVER_GRAPH),
      "gold_triples" => count(client, GOLD_GRAPH),
      "silver_subjects" => count_distinct(client, SILVER_GRAPH)
    }
    history = (journal || JournalReader).read
    {
      "counts" => counts,
      "last_promotion" => history[:last_promotion],
      "shacl_reports" => history[:shacl_reports],
      "rag" => {
        "status" => "unindexed",
        "reason" => "rag_write_undecided: Silver has never been embedded; " \
                    "no vector writes exist, so there is no collection health to report"
      }
    }
  end

  def count(client, graph)
    res = client.query(
      "# stat:count\nSELECT (COUNT(*) AS ?n) WHERE { GRAPH <#{graph}> { ?s ?p ?o } }"
    )
    integer_cell(res, "n")
  end
  private_class_method :count

  def count_distinct(client, graph)
    res = client.query(
      "# stat:subjects\nSELECT (COUNT(DISTINCT ?s) AS ?n) WHERE { GRAPH <#{graph}> { ?s ?p ?o } }"
    )
    integer_cell(res, "n")
  end
  private_class_method :count_distinct

  def integer_cell(res, key)
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", { "detail" => "stat count failed: #{res.inspect[0, 200]}" })
    end

    Array(res[:rows]).first&.fetch(key, 0).to_i
  end
  private_class_method :integer_cell

  # Journal history: last completed promote plus recent SHACL report ids.
  # Reports ride the conform/promote receipts (result contexts); the ids
  # reported are the receipt cids, which is where an operator replays
  # from. Separated for injection: the wire passes nothing, tests pass a
  # stub.
  module JournalReader
    module_function

    def read
      promote = RailsOsiLevel8::OperationRequest.admitted
                .where(operation_name: "memory.promote")
                .order(recorded_at: :desc).limit(1).first
      last = nil
      unless promote.nil? || promote.receipt.nil?
        last = {
          "operation" => "memory.promote",
          "operation_request_cid" => promote.cid,
          "receipt_cid" => promote.receipt.cid,
          "completed_at" => promote.receipt.completed_at&.iso8601
        }.compact
      end

      # The RECEIPT cid, not result_context_cid. conform and promote
      # carry their gate report in the receipt result (shacl_engine +
      # shacl_violations); they never write a separate result context,
      # so reading result_context_cid returned nil for every row and
      # this list was structurally always empty -- a field that named
      # something it could not report. The receipt cid is what an
      # operator replays from, which is what the contract meant.
      reports = RailsOsiLevel8::ExecutionReceipt
                .joins(:operation_request)
                .where(osi_l8_operation_requests: { operation_name: %w[memory.conform memory.promote] })
                .order("osi_l8_execution_receipts.recorded_at DESC").limit(10)
                .filter_map(&:cid).uniq
      { last_promotion: last, shacl_reports: reports }
    end
  end

  # Runtime twin for Memory::StatPullShape: a pull with no parameters
  # beyond the envelope.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    v
  end

  # Runtime twin for Memory::StatContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a stat response carries exactly one report" } if item.nil?
    if item
      counts = item["counts"]
      if !counts.is_a?(Hash)
        v << { path: "counts", message: "stat must report per-graph counts" }
      else
        %w[bronze_triples silver_triples gold_triples].each do |k|
          v << { path: k, message: "stat must count #{k}" } unless counts[k].is_a?(Integer)
        end
      end
      if !item["rag"].is_a?(Hash) || blank?(item.dig("rag", "status"))
        v << { path: "rag", message: "stat must report rag health, even when unindexed" }
      end
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
