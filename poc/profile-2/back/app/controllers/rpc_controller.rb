require "json"

# The Level-8 (Profile 2) endpoint. JSON-RPC-LD in, never-raise results out.
class RpcController < ApplicationController
  CONTEXT = "https://osi8.poc/context/profile-2"

  def manifest
    CanonicalStore.seed!
    render json: ld(CanonicalStore.manifest)
  end

  def call
    CanonicalStore.seed!
    req = JSON.parse(request.body.read)
    id = req["id"]; m = req["method"]; p = req["params"] || {}
    result =
      case m
      when "methods.list"    then CanonicalStore.manifest["methods"]
      when "canonical.pull"  then CanonicalStore.pull(type: p["type"])
      when "canonical.get"   then CanonicalStore.get(p["id"])
      when "insight.push"     then CanonicalStore.push_insight(operation_id: p["operationId"], insight: p["insight"])
      when "row.push"         then CanonicalStore.push_row(operation_id: p["operationId"], row: p["row"])
      else return render json: { "jsonrpc"=>"2.0", "error"=>{"code"=>-32601,"message"=>"method not found: #{m}"}, "id"=>id }
      end
    render json: { "jsonrpc"=>"2.0", "result"=>ld(result), "id"=>id }
  rescue JSON::ParserError
    render json: { "jsonrpc"=>"2.0", "error"=>{"code"=>-32700,"message"=>"parse error"}, "id"=>nil }
  end
  private

  # JSON-RPC-LD: ground the response result with an @context. A collection becomes a
  # JSON-LD @graph; records inside already carry @id/@type.
  def ld(r)
    return { "@context"=>CONTEXT, "@graph"=>r } if r.is_a?(Array)
    return { "@context"=>CONTEXT }.merge(r) if r.is_a?(Hash)
    r
  end
end
