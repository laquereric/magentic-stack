require "digest"

# POC in-memory canonical store. BACK is the SOLE WRITER. Demonstrates Profile 2:
# a published API surface; a referenceable sales Dataset (Context by reference); an
# Insight write path; and a TABLE the LLM writes rows into, where the table's COLUMN
# SHAPE is derived into the row contract -- the shape drives (and validates) the output.
class CanonicalStore
  @records = {}
  @applied = {}
  @rows = {}    # month(1..12) => the row the LLM wrote (sales-pivot table cells)

  MONTHS   = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
  SEASONAL = {1=>0.85,2=>0.80,3=>0.95,4=>1.00,5=>1.05,6=>1.10,7=>1.05,8=>1.00,9=>1.05,10=>1.15,11=>1.35,12=>1.55}.freeze
  GROWTH   = (1..12).each_with_object({}) { |m,h| h[m] = 1.05 + m * 0.005 }.freeze  # Jan 1.055 .. Dec 1.115 -> per-month %change varies
  YEARS    = (2021..2025).to_a.freeze

  INSIGHT_SHAPE = {
    "@type"=>"Insight", "sh:closed"=>true, "required"=>["@type","question","answer"],
    "properties"=>{ "@type"=>{"const"=>"Insight"}, "question"=>"xsd:string", "answer"=>"xsd:string",
                    "seasonal"=>"xsd:boolean", "evidence"=>"xsd:string" }
  }.freeze

  class << self
    def seed!
      return unless @records.empty?
      series = []
      YEARS.each { |y| (1..12).each { |m| series << { "year"=>y, "month"=>m, "sales"=>(100_000 * SEASONAL[m] * (GROWTH[m] ** (y - 2021))).round } } }
      dsid = iri("dataset/sales-by-month")
      @records[dsid] = { "@id"=>dsid, "@type"=>"Dataset", "sf:version"=>1, "title"=>"Monthly sales, 2021-2025 (USD)", "unit"=>"USD", "points"=>series.size, "series"=>series }
      tsid = iri("table/sales-pivot")
      @records[tsid] = sales_pivot_spec.merge("@id"=>tsid, "sf:version"=>1)
    end

    def sales_pivot_spec
      cols = ["month"] + YEARS.map { |y| "y#{y}" } + ["pct_change"]
      types = cols.each_with_object({}) { |c,h| h[c] = (c == "month" ? "xsd:string" : "xsd:decimal") }
      { "@type"=>"TableSpec", "title"=>"Sales by month x year, with % change (#{YEARS.first}->#{YEARS.last})",
        "row_key"=>"month", "columns"=>cols, "column_types"=>types }
    end

    # The row shape is DERIVED from the table columns: the SHAPE DRIVES THE OUTPUT.
    def row_shape
      s = sales_pivot_spec
      props = { "@type"=>{"const"=>"Row"}, "table"=>"IRI" }
      s["columns"].each { |c| props[c] = s["column_types"][c] }
      { "@type"=>"Row", "sh:closed"=>true, "table"=>iri("table/sales-pivot"),
        "required"=>(["@type","table"] + s["columns"]), "properties"=>props }
    end

    def manifest
      { "methods"=>[
        { "@id"=>iri("method/methods.list"),   "name"=>"methods.list",   "params"=>{},                  "result"=>"method descriptors" },
        { "@id"=>iri("method/canonical.pull"), "name"=>"canonical.pull", "params"=>{"type"=>"string?"}, "result"=>"bounded previews {@id,@type,sf:version,preview}" },
        { "@id"=>iri("method/canonical.get"),  "name"=>"canonical.get",  "params"=>{"id"=>"IRI"},       "result"=>"full record; a TableSpec includes its shape + written rows" },
        { "@id"=>iri("method/insight.push"),   "name"=>"insight.push",   "params"=>{"operationId"=>"string","insight"=>"Insight"}, "shape"=>INSIGHT_SHAPE, "result"=>"signed receipt + stored Insight" },
        { "@id"=>iri("method/row.push"),       "name"=>"row.push",       "params"=>{"operationId"=>"string","row"=>"Row"},        "shape"=>row_shape,     "result"=>"signed receipt; row written to the sales-pivot table" }
      ] }
    end

    def pull(type: nil)
      @records.values.select { |r| type.nil? || r["@type"] == type }
        .map { |r| { "@id"=>r["@id"], "@type"=>r["@type"], "sf:version"=>r["sf:version"], "preview"=>preview_of(r) } }
    end

    def get(id)
      r = @records[id]
      return refuse(:unknown_id, "no record #{id}") unless r
      return { "ok"=>true, "record"=>r.merge("shape"=>row_shape, "rows"=>rows_sorted) } if r["@type"] == "TableSpec"
      { "ok"=>true, "record"=>r }
    end

    def push_insight(operation_id:, insight:)
      return @applied[operation_id].merge("idempotent"=>true) if operation_id && @applied[operation_id]
      if (why = validate_insight(insight)) then return refuse(:shape_violation, why) end
      id = iri("insight/#{@applied.size + 1}")
      rec = { "@id"=>id, "sf:version"=>1 }.merge(insight)
      @records[id] = rec
      receipt = { "ok"=>true, "@id"=>id, "sf:version"=>1, "operationId"=>operation_id, "stored"=>rec, "receipt"=>sign(id, 1, operation_id) }
      @applied[operation_id] = receipt if operation_id
      receipt
    end

    # An Effect written by the LLM INTO the BACK table, validated against the shape-derived row contract.
    def push_row(operation_id:, row:)
      return @applied[operation_id].merge("idempotent"=>true) if operation_id && @applied[operation_id]
      if (why = validate_row(row)) then return refuse(:shape_violation, why) end
      m = MONTHS.index(row["month"]) + 1
      @rows[m] = row.merge("sf:version"=>1)
      receipt = { "ok"=>true, "month"=>row["month"], "operationId"=>operation_id, "written"=>@rows[m], "receipt"=>sign(row["month"], 1, operation_id) }
      @applied[operation_id] = receipt if operation_id
      receipt
    end

    private
    def rows_sorted = (1..12).map { |m| @rows[m] }.compact
    def preview_of(r)
      case r["@type"]
      when "Dataset"   then "Dataset: #{r['title']} -- #{r['points']} monthly points (#{r['unit']})"
      when "TableSpec" then "TableSpec: #{r['title']}; columns [#{r['columns'].join(', ')}]; #{@rows.size}/12 rows written"
      when "Insight"   then "Insight: #{r['question']} -- #{r['answer'].to_s[0,50]}"
      else "#{r['@type']}: #{r['@id']}"
      end
    end
    def validate_row(e)
      s = row_shape
      return "not an object" unless e.is_a?(Hash)
      return "@type must be Row" unless e["@type"] == "Row"
      return "wrong table" unless e["table"] == s["table"]
      miss = s["required"].reject { |k| e.key?(k) }
      return "missing #{miss.join(',')}" if miss.any?
      return "unknown month #{e['month']}" unless MONTHS.include?(e["month"])
      extra = e.keys - s["properties"].keys
      return "closed shape: unexpected #{extra.join(',')}" if extra.any?
      nonnum = (sales_pivot_spec["columns"] - ["month"]).reject { |c| e[c].is_a?(Numeric) }
      return "non-numeric #{nonnum.join(',')}" if nonnum.any?
      nil
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
