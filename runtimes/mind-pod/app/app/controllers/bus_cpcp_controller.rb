# frozen_string_literal: true

# ROLE=bus CPCP surface (row 18). POST /_cpcp/rpc.
# Do NOT mount RailsCpcp::Engine: stock RpcController always renders HTTP 200
# (row 49 KEEP BOTH) and the engine's catalog is BACK's note.create.
# No RES. One method. BACK does not call this process (row 72).
class BusCpcpController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  METHODS = {
    "bus.projection.latest" => :latest
  }.freeze

  def rpc
    parsed = parse_rpc
    unless parsed[:error].nil?
      return reply(id: parsed[:id], status: 400,
                   json: fail_json(parsed[:error], parsed[:because]))
    end
    op = METHODS[parsed[:method]]
    unless op
      return reply(id: parsed[:id], status: 400,
                   json: fail_json("unknown_operation", { "method" => parsed[:method] }))
    end
    result = perform_bus(op)
    reply(id: parsed[:id], status: result[:status], json: result[:json])
  end

  private

  def perform_bus(op)
    case op
    when :latest
      derived = Bus::Projector.latest
      { status: 200, json: { "ok" => true, "result" => derived } }
    end
  rescue DomainWriters::Refused => e
    { status: 403, json: fail_json("domain_write_refused", { "role" => e.role, "model" => e.model_name }) }
  end

  def parse_rpc
    raw = request.body.read
    if raw.to_s.strip.empty?
      return { id: nil, error: "empty_body", because: { "offender" => "body" } }
    end
    parsed = JSON.parse(raw)
    unless parsed.is_a?(Hash)
      return { id: nil, error: "unparseable_json", because: { "offender" => "body" } }
    end
    params = parsed["params"]
    params = {} if params.nil?
    unless params.is_a?(Hash)
      return { id: parsed["id"], error: "unparseable_json", because: { "offender" => "params" } }
    end
    { id: parsed["id"], method: parsed["method"].to_s, params: params, error: nil }
  rescue JSON::ParserError
    { id: nil, error: "unparseable_json", because: { "offender" => "body" } }
  end

  def fail_json(reason, because)
    { "ok" => false, "reason" => reason.to_s, "because" => because }
  end

  def reply(id:, status:, json:)
    json = json.merge("jsonrpc" => "2.0", "id" => id)
    render json: json, status: status
  end
end
