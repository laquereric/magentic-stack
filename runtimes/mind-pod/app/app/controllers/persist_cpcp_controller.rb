# frozen_string_literal: true

# ROLE=persist placement authority (row 8). POST /_cpcp/rpc.
# Do NOT mount RailsCpcp::Engine: stock RpcController always renders HTTP 200
# (row 49 KEEP BOTH) and the engine's catalog is BACK's note.create.
#
# Records next-boot placement intentions against the row-39 closed set
# (config/store_bindings.json — the same file the deploy gate enforces).
# Nothing here applies live: a path change is a restart (ROW41 S2), so
# every set responds with live_applied:false and the refusal half of row 41
# is structural — there is no live swap to refuse, only invalid placements.
class PersistCpcpController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  METHODS = {
    "persist.path.set" => :set,
    "persist.path.get" => :get,
  }.freeze

  OPS = { set: "set", get: "get" }.freeze

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
    begin
      access = Persist::Access.parse!(ENV["PERSIST_CALLERS"])
      caller = access.authenticate!(bearer)
      access.authorize!(caller, OPS[op])
      sets = Persist::ClosedSet.read!
    rescue Persist::Access::Unparseable, Persist::ClosedSet::Error => e
      return reply(id: parsed[:id], status: 500, json: fail_json(e.reason, e.because))
    rescue Persist::Access::Unauthenticated => e
      return reply(id: parsed[:id], status: 401, json: fail_json(e.reason, e.because))
    rescue Persist::Access::Forbidden => e
      return reply(id: parsed[:id], status: 403, json: fail_json(e.reason, e.because))
    end
    result = perform_persist(op, parsed[:params], caller, sets)
    reply(id: parsed[:id], status: result[:status], json: result[:json])
  end

  private

  def perform_persist(op, params, caller, sets)
    case op
    when :set then path_set(params, caller, sets)
    when :get then path_get(params, sets)
    end
  rescue DomainWriters::Refused => e
    { status: 403, json: fail_json("domain_write_refused", { "role" => e.role, "model" => e.model_name }) }
  end

  def path_set(params, caller, sets)
    store = params["store"].to_s
    path = params["path"].to_s
    unless sets.key?(store)
      return { status: 400, json: fail_json("unknown_store", { "store" => store, "known" => sets.keys.sort }) }
    end
    unless sets.values.any? { |s| s["path"] == path }
      return { status: 400, json: fail_json("unknown_path", { "path" => path, "because" => "not a closed-set member" }) }
    end
    row = PersistPlacement.find_by(store: store)
    previous = row&.path
    now = Time.now.utc
    if row
      row.update!(path: path, set_by: caller.id, recorded_at: now)
    else
      PersistPlacement.create!(store: store, path: path, set_by: caller.id, recorded_at: now)
    end
    { status: 200, json: { "ok" => true, "result" => {
      "store" => store, "path" => path, "previous_path" => previous,
      "set_by" => caller.id, "live_applied" => false, "effective" => "next_boot"
    } } }
  end

  def path_get(params, sets)
    store = params["store"].to_s
    unless sets.key?(store)
      return { status: 400, json: fail_json("unknown_store", { "store" => store, "known" => sets.keys.sort }) }
    end
    row = PersistPlacement.find_by(store: store)
    result = if row
               { "store" => store, "recorded" => true, "path" => row.path,
                 "set_by" => row.set_by, "recorded_at" => row.recorded_at.utc.iso8601 }
             else
               { "store" => store, "recorded" => false, "path" => nil }
             end
    { status: 200, json: { "ok" => true, "result" => result } }
  end

  def bearer
    h = request.headers["Authorization"].to_s
    h.start_with?("Bearer ") ? h.delete_prefix("Bearer ").strip : ""
  end

  def parse_rpc
    raw = request.body.read
    if raw.to_s.strip.empty?
      return { id: nil, error: "empty_body", because: { "offender" => "body" } }
    end
    parsed = JSON.parse(raw)
    unless parsed.is_a?(Hash)
      return { id: parsed["id"], error: "unparseable_json", because: { "offender" => "body" } }
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
    response.set_header("WWW-Authenticate", "Bearer") if status.to_i == 401
    render json: json, status: status
  end
end
