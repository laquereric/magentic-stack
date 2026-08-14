require "digest"

# POC in-memory canonical store. BACK is the SOLE WRITER; a real deployment persists
# to SQLite. Demonstrates the Profile 2 surface: a published API surface, bounded
# previews (Context by reference), on-demand dereference, and typed Effects validated
# against a CLOSED shape with operationId idempotency + baseVersion concurrency.
class CanonicalStore
  @records = {}   # @id => record
  @applied = {}   # operationId => receipt (idempotency)
  @seq = 0

  class << self
    def seed!
      return unless @records.empty?
      ["Draft the Q3 report", "Review the migration plan", "Email the client"].each do |t|
        create!(fields: { "title"=>t, "status"=>"open" })
      end
    end

    def task_effect_shape
      { "@type"=>"Task", "sh:closed"=>true, "required"=>["@id","@type","title","status"],
        "properties"=>{ "@id"=>"IRI", "@type"=>{"const"=>"Task"}, "title"=>"xsd:string",
                        "status"=>{"enum"=>["open","doing","done"]} } }
    end

    def manifest
      { "methods" => [
        { "@id"=>iri("method/methods.list"),    "name"=>"methods.list",    "params"=>{},                     "result"=>"method descriptors" },
        { "@id"=>iri("method/canonical.pull"),  "name"=>"canonical.pull",  "params"=>{"type"=>"string?"},    "result"=>"bounded previews {@id,@type,sf:version,preview}" },
        { "@id"=>iri("method/canonical.get"),   "name"=>"canonical.get",   "params"=>{"id"=>"IRI"},          "result"=>"full grounded record" },
        { "@id"=>iri("method/syncIntent.push"), "name"=>"syncIntent.push", "params"=>{"operationId"=>"string","baseVersion"=>"int","effect"=>"Task"}, "shape"=>task_effect_shape, "result"=>"signed receipt" }
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

    def push(operation_id:, base_version:, effect:)
      return @applied[operation_id].merge("idempotent"=>true) if operation_id && @applied[operation_id]
      if (why = validate(effect)) then return refuse(:shape_violation, why) end
      id = effect["@id"]; rec = @records[id]
      return refuse(:unknown_target, "no target #{id}") unless rec
      return refuse(:version_conflict, "baseVersion #{base_version} != #{rec['sf:version']}") unless base_version == rec["sf:version"]
      rec.merge!("title"=>effect["title"], "status"=>effect["status"], "sf:version"=>rec["sf:version"] + 1)
      receipt = { "ok"=>true, "@id"=>id, "sf:version"=>rec["sf:version"], "operationId"=>operation_id,
                  "receipt"=>sign(id, rec["sf:version"], operation_id) }
      @applied[operation_id] = receipt if operation_id
      receipt
    end

    private
    def create!(fields:)
      @seq += 1; id = iri("task/#{@seq}")
      @records[id] = { "@id"=>id, "@type"=>"Task", "sf:version"=>1 }.merge(fields)
    end
    def preview_of(r) = "#{r['@type']}: #{r['title'].to_s[0,40]} [#{r['status']}]"
    def validate(e)
      s = task_effect_shape
      return "not an object" unless e.is_a?(Hash)
      miss = s["required"].reject { |k| e.key?(k) }
      return "missing #{miss.join(',')}" if miss.any?
      return "@type must be Task" unless e["@type"] == "Task"
      return "status not allowed" unless %w[open doing done].include?(e["status"])
      extra = e.keys - s["properties"].keys
      return "closed shape: unexpected #{extra.join(',')}" if extra.any?
      nil
    end
    def refuse(reason, because) = { "ok"=>false, "reason"=>reason.to_s, "because"=>because }
    def sign(id, v, op) = Digest::SHA256.hexdigest("#{id}|#{v}|#{op}|poc")[0,16]
    def iri(path) = "https://osi8.poc/#{path}"
  end
end
