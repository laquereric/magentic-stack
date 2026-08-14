require "json"

# The Cyborg Channel (Profile 1) endpoint. JSON-RPC-LD in, never-raise results out.
class RpcController < ApplicationController
  CONTEXT = "https://osi8.poc/context/cyborg-channel"

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
      when "canonical.pull"  then CanonicalStore.pull
      when "canonical.get"   then CanonicalStore.get(p["id"])
      when "syncIntent.push" then CanonicalStore.push(operation_id: p["operationId"], base_version: p["baseVersion"], patch: p["patch"])
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
