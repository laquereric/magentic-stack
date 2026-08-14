require "digest"

# POC in-memory CANONICAL ledger for the Cyborg Channel (Profile 1). BACK is the
# SOLE WRITER. The FRONT mirrors these records, edits offline, and proposes changes
# as sync_intents. A push is applied under operationId idempotency + baseVersion
# optimistic concurrency, validated against a closed Note shape. private_local never
# reaches this server.
class CanonicalStore
  @records = {}   # @id => Note
  @applied = {}   # operationId => receipt

  NOTE_SHAPE = { "@type"=>"Note", "sh:closed"=>true, "required"=>["@id","@type","title","body"],
                 "properties"=>{ "@id"=>"IRI", "@type"=>{"const"=>"Note"}, "title"=>"xsd:string", "body"=>"xsd:string" } }.freeze

  class << self
    def seed!
      return unless @records.empty?
      create!("Welcome", "This canonical note lives on the server (BACK).")
      create!("Roadmap", "Mirror me, edit me offline, and sync your changes back.")
    end

    def manifest
      { "methods"=>[
        { "@id"=>iri("method/methods.list"),   "name"=>"methods.list",   "params"=>{},                                              "result"=>"method descriptors" },
        { "@id"=>iri("method/canonical.pull"), "name"=>"canonical.pull", "params"=>{},                                              "result"=>"the canonical Note records to mirror {@id,@type,title,body,sf:version}" },
        { "@id"=>iri("method/canonical.get"),  "name"=>"canonical.get",  "params"=>{"id"=>"IRI"},                                    "result"=>"one canonical record" },
        { "@id"=>iri("method/syncIntent.push"),"name"=>"syncIntent.push", "params"=>{"operationId"=>"string","baseVersion"=>"int","patch"=>"Note"}, "shape"=>NOTE_SHAPE, "result"=>"signed receipt or version_conflict" }
      ] }
    end

    def pull
      @records.values.map { |r| r.dup }
    end

    def get(id)
      r = @records[id]
      return refuse(:unknown_id, "no record #{id}") unless r
      { "ok"=>true, "record"=>r }
    end

    # A proposed change from the FRONT. Create when @id is new; otherwise update under baseVersion.
    def push(operation_id:, base_version:, patch:)
      return @applied[operation_id].merge("idempotent"=>true) if operation_id && @applied[operation_id]
      if (why = validate(patch)) then return refuse(:shape_violation, why) end
      id = patch["@id"]; rec = @records[id]
      if rec.nil?
        @records[id] = { "@id"=>id, "@type"=>"Note", "title"=>patch["title"], "body"=>patch["body"], "sf:version"=>1 }
        v = 1
      else
        return refuse(:version_conflict, "#{id} is at version #{rec['sf:version']}, intent was authored against #{base_version}") unless base_version == rec["sf:version"]
        rec.merge!("title"=>patch["title"], "body"=>patch["body"], "sf:version"=>rec["sf:version"] + 1)
        v = rec["sf:version"]
      end
      receipt = { "ok"=>true, "@id"=>id, "sf:version"=>v, "operationId"=>operation_id, "receipt"=>sign(id, v, operation_id) }
      @applied[operation_id] = receipt if operation_id
      receipt
    end

    private
    def create!(title, body)
      id = iri("note/#{@records.size + 1}")
      @records[id] = { "@id"=>id, "@type"=>"Note", "title"=>title, "body"=>body, "sf:version"=>1 }
    end
    def validate(e)
      s = NOTE_SHAPE
      return "not an object" unless e.is_a?(Hash)
      miss = s["required"].reject { |k| e.key?(k) }
      return "missing #{miss.join(',')}" if miss.any?
      return "@type must be Note" unless e["@type"] == "Note"
      extra = e.keys - s["properties"].keys
      return "closed shape: unexpected #{extra.join(',')}" if extra.any?
      nil
    end
    def refuse(reason, because) = { "ok"=>false, "reason"=>reason.to_s, "because"=>because }
    def sign(id, v, op) = Digest::SHA256.hexdigest("#{id}|#{v}|#{op}|poc")[0,16]
    def iri(path) = "https://osi8.poc/#{path}"
  end
end
