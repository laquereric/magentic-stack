require "json"

# The Level-8 (Profile 2) endpoint. JSON-RPC-LD in, never-raise results out.
class RpcController < ApplicationController
  def manifest
    CanonicalStore.seed!
    render json: CanonicalStore.manifest
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
      else return render json: { "jsonrpc"=>"2.0", "error"=>{"code"=>-32601,"message"=>"method not found: #{m}"}, "id"=>id }
      end
    render json: { "jsonrpc"=>"2.0", "result"=>result, "id"=>id }
  rescue JSON::ParserError
    render json: { "jsonrpc"=>"2.0", "error"=>{"code"=>-32700,"message"=>"parse error"}, "id"=>nil }
  end
end
