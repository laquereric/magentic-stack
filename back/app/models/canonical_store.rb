require "digest"

# POC in-memory canonical store. BACK is the SOLE WRITER. Demonstrates Profile 2:
# a published API surface, a REFERENCEABLE dataset (Context by reference -- bounded
# preview + on-demand dereference), and a structured-output write path (insight.push)
# validated against a CLOSED shape, with operationId idempotency.
class CanonicalStore
  @records = {}
  @applied = {}
  @seq = 0

  # A clear seasonal shape (holiday peak in Nov/Dec, winter trough) + ~8%/yr growth.
  SEASONAL = {1=>0.85,2=>0.80,3=>0.95,4=>1.00,5=>1.05,6=>1.10,7=>1.05,8=>1.00,9=>1.05,10=>1.15,11=>1.35,12=>1.55}.freeze

  INSIGHT_SHAPE = {
    "@type"=>"Insight", "sh:closed"=>true, "required"=>["@type","question","answer"],
    "properties"=>{ "@type"=>{"const"=>"Insight"}, "question"=>"xsd:string", "answer"=>"xsd:string",
                    "seasonal"=>"xsd:boolean", "evidence"=>"xsd:string" }
  }.freeze

  class << self
    def seed!
      return unless @records.empty?
      series = []
      (2021..2025).each do |y|
        (1..12).each do |m|
          series << { "year"=>y, "month"=>m, "sales"=>(100_000 * SEASONAL[m] * (1.08 ** (y - 2021))).round }
        end
      end
      id = iri("dataset/sales-by-month")
      @records[id] = { "@id"=>id, "@type"=>"Dataset", "sf:version"=>1,
                       "title"=>"Monthly sales, 2021-2025 (USD)", "unit"=>"USD",
                       "points"=>series.size, "series"=>series }
    end

    def manifest
      { "methods" => [
        { "@id"=>iri("method/methods.list"),   "name"=>"methods.list",   "params"=>{},                  "result"=>"method descriptors" },
        { "@id"=>iri("method/canonical.pull"), "name"=>"canonical.pull", "params"=>{"type"=>"string?"}, "result"=>"bounded previews {@id,@type,sf:version,preview}" },
        { "@id"=>iri("method/canonical.get"),  "name"=>"canonical.get",  "params"=>{"id"=>"IRI"},       "result"=>"full grounded record (dereference on demand)" },
        { "@id"=>iri("method/insight.push"),   "name"=>"insight.push",   "params"=>{"operationId"=>"string","insight"=>"Insight"}, "shape"=>INSIGHT_SHAPE, "result"=>"signed receipt + stored Insight" }
      ] }
    end

    def pull(type: nil)
      @records.values.select { |r| type.nil? || r["@type"] == type }
        .map { |r| { "@id"=>r["@id"], "@type"=>r["@type"], "sf:version"=>r["sf:version"], "preview"=>preview_of(r) } }
    end

    def get(id)
      r = @records[id]
      return refuse(:unknown_id, "no record #{id}") unless r
      { "ok"=>true, "record"=>r }
    end

    def push_insight(operation_id:, insight:)
      return @applied[operation_id].merge("idempotent"=>true) if operation_id && @applied[operation_id]
      if (why = validate_insight(insight)) then return refuse(:shape_violation, why) end
      @seq += 1; id = iri("insight/#{@seq}")
      rec = { "@id"=>id, "sf:version"=>1 }.merge(insight)
      @records[id] = rec
      receipt = { "ok"=>true, "@id"=>id, "sf:version"=>1, "operationId"=>operation_id, "stored"=>rec, "receipt"=>sign(id, 1, operation_id) }
      @applied[operation_id] = receipt if operation_id
      receipt
    end

    private
    def preview_of(r)
      case r["@type"]
      when "Dataset" then "Dataset: #{r['title']} -- #{r['points']} monthly points (#{r['unit']})"
      when "Insight" then "Insight: #{r['question']} -- #{r['answer'].to_s[0,60]}"
      else "#{r['@type']}: #{r['@id']}"
      end
    end
    def validate_insight(e)
      s = INSIGHT_SHAPE
      return "not an object" unless e.is_a?(Hash)
      miss = s["required"].reject { |k| e.key?(k) }
      return "missing #{miss.join(',')}" if miss.any?
      return "@type must be Insight" unless e["@type"] == "Insight"
      return "seasonal must be boolean" if e.key?("seasonal") && ![true, false].include?(e["seasonal"])
      extra = e.keys - s["properties"].keys
      return "closed shape: unexpected #{extra.join(',')}" if extra.any?
      nil
    end
    def refuse(reason, because) = { "ok"=>false, "reason"=>reason.to_s, "because"=>because }
    def sign(id, v, op) = Digest::SHA256.hexdigest("#{id}|#{v}|#{op}|poc")[0,16]
    def iri(path) = "https://osi8.poc/#{path}"
  end
end
