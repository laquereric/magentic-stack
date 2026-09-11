# frozen_string_literal: true

# ROLE=rag retrieval seam. POST /_cpcp/rpc.
#
# Option 3 of RagContainer.md: a Rails ROLE IS the rag.* contract, and the
# Milvus engine stays the official third-party image, unforked and
# digest-pinned. BACK does not register rag.*; indexing is a CALL to this seam,
# so domain admission stays on BACK (ADR 0052, 0056).
#
# Do NOT mount RailsCpcp::Engine: stock RpcController always renders HTTP 200,
# and the engine's catalog is BACK's note.create. Same reason persist and bus
# draw their own route.
#
# Talks to Milvus over its REST v2 API rather than gRPC. Milvus serves both on
# 19530 and Ruby has no maintained gRPC client for it; REST is the same engine,
# reached without vendoring a protocol stack into the pod.
#
# WHAT IS NOT HERE, AND WHY
#
# rag.upsert and rag.delete are declared and REFUSED. RagContainer.md leaves
# one question to the ADR -- who embeds: the caller supplies the vector, or
# this face calls switch and then stores -- and says "pick one in the ADR; do
# not do both silently". Until that is decided, a write path here would be the
# silent pick. A refusal that names the undecided question is the honest state;
# an implementation that guessed would be worse than no implementation, because
# it would look decided.
class RagCpcpController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  METHODS = {
    "rag.stat" => :stat,
    "rag.search" => :search,
    "rag.upsert" => :upsert,
    "rag.delete" => :delete,
  }.freeze

  def rpc
    parsed = parse_rpc
    unless parsed[:error].nil?
      return reply(id: parsed[:id], status: 400, json: fail_json(parsed[:error], parsed[:because]))
    end

    op = METHODS[parsed[:method]]
    unless op
      return reply(id: parsed[:id], status: 400,
                   json: fail_json("unknown_operation",
                                   { "method" => parsed[:method], "known" => METHODS.keys.sort }))
    end

    result = perform(op, parsed[:params] || {})
    reply(id: parsed[:id], status: result[:status], json: result[:json])
  end

  private

  def perform(op, params)
    case op
    when :stat then stat(params)
    when :search then search(params)
    when :upsert, :delete then undecided_write(op)
    end
  end

  # Collection existence and counts. Never a default-collection lie: an absent
  # collection is a refusal, and an empty one is ok with n: 0. Those are
  # different answers and the caller is entitled to tell them apart.
  def stat(params)
    name = params["collection"].to_s
    listed = milvus("/v2/vectordb/collections/list", {})
    return listed[:refusal] if listed[:refusal]

    collections = Array(listed[:data])
    return { status: 200, json: { "ok" => true, "result" => { "collections" => collections.sort } } } if name.empty?

    unless collections.include?(name)
      return { status: 404, json: fail_json("collection_missing",
                                            { "collection" => name, "known" => collections.sort }) }
    end

    counted = milvus("/v2/vectordb/entities/query",
                     { "collectionName" => name, "filter" => "", "outputFields" => ["count(*)"] })
    return counted[:refusal] if counted[:refusal]

    n = Array(counted[:data]).first&.fetch("count(*)", nil)
    { status: 200, json: { "ok" => true, "result" => { "collection" => name, "n" => n.to_i } } }
  end

  # Nearest chunks, not a generation. Returns ids and scores; what to do with
  # them is the caller's business and the LLM stays on switch.
  def search(params)
    name = params["collection"].to_s
    return { status: 400, json: fail_json("collection_required", { "because" => "rag.search names one collection" }) } if name.empty?

    vector = params["vector"]
    unless vector.is_a?(Array) && !vector.empty?
      # Text-only search needs an embedding, which needs the undecided write
      # path's answer about who embeds. Refuse rather than pick.
      return { status: 400, json: fail_json("vector_required",
                                            { "because" => "supply `vector`; embedding here is undecided (RagContainer.md, who embeds)" }) }
    end

    found = milvus("/v2/vectordb/entities/search", {
      "collectionName" => name,
      "data" => [vector],
      "limit" => (params["limit"] || 10).to_i,
      "outputFields" => Array(params["outputFields"] || ["id"]),
    })
    return found[:refusal] if found[:refusal]

    { status: 200, json: { "ok" => true, "result" => { "collection" => name, "hits" => Array(found[:data]) } } }
  end

  def undecided_write(op)
    { status: 501, json: fail_json("rag_write_undecided", {
      "method" => "rag.#{op}",
      "because" => "RagContainer.md leaves who embeds to the ADR -- caller supplies the vector, " \
                   "or this face calls switch then stores. Implementing one here would be the " \
                   "silent pick it warns against.",
      "also" => "a chunk with no operationId is refused; an agent cannot mark its own retrieval effect committed",
    }) }
  end

  # One call site for the engine. Never raises: a store that is down is a
  # refusal with a reason, not a 500 with a backtrace.
  def milvus(path, body)
    base = ENV["MILVUS_URL"].to_s
    if base.empty?
      return { refusal: { status: 503, json: fail_json("rag_not_configured", { "because" => "MILVUS_URL unset" }) } }
    end

    uri = URI.join(base, path)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(body)
    res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 3, read_timeout: 15) { |http| http.request(req) }

    parsed = begin
      JSON.parse(res.body.to_s)
    rescue JSON::ParserError
      nil
    end
    if parsed.nil?
      return { refusal: { status: 502, json: fail_json("rag_unparseable", { "status" => res.code.to_i }) } }
    end
    # Milvus reports its own failures in-band with code != 0, so an HTTP 200
    # is not by itself a success.
    if parsed["code"].to_i != 0
      return { refusal: { status: 502, json: fail_json("rag_engine_refused",
                                                       { "code" => parsed["code"], "message" => parsed["message"] }) } }
    end
    { data: parsed["data"] }
  rescue StandardError => e
    { refusal: { status: 503, json: fail_json("rag_unreachable", { "because" => "#{e.class}: #{e.message}" }) } }
  end

  def parse_rpc
    body = JSON.parse(request.raw_post.to_s.empty? ? "{}" : request.raw_post)
    return { error: "unparseable_json", because: { "because" => "body is not an object" } } unless body.is_a?(Hash)

    { id: body["id"], method: body["method"].to_s, params: body["params"], error: nil }
  rescue JSON::ParserError => e
    { error: "unparseable_json", because: { "because" => e.message } }
  end

  def fail_json(reason, because)
    { "ok" => false, "reason" => reason, "because" => because }
  end

  def reply(id:, status:, json:)
    render json: json.merge("jsonrpc" => "2.0", "id" => id), status: status
  end
end
