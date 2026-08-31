# frozen_string_literal: true
module RailsCpcp
  # Executes one operation call against the registry and returns a JSON-RPC-LD
  # response envelope. NEVER raises across the boundary.
  module Dispatcher
    module_function

    # request: parsed hash { "method", "params", "id", "operationId" }
    # ctx: opaque per-request context handed to handlers (controller, current_user, ...)
    def call(request, ctx: nil, idempotency: RailsCpcp.idempotency_store)
      id = request["id"]
      method = request["method"].to_s
      params = request["params"] || {}
      opid = nil
      op = Registry.find(method)
      unless op
        env = Envelope.fail(id: id, reason: :unknown_operation, because: "no CPCP operation #{method.inspect}")
        RefusalLog.observe_envelope(env, source: "dispatcher", method: method)
        return env
      end

      missing = op.params - params.keys
      unless missing.empty?
        env = Envelope.fail(id: id, reason: :missing_params, because: "missing #{missing.join(', ')}")
        RefusalLog.observe_envelope(env, source: "dispatcher", method: method)
        return env
      end

      opid = (request["operationId"] || params["operationId"]).to_s
      if op.direction == :push
        if opid.empty?
          env = Envelope.fail(id: id, reason: :operation_id_required, because: "PUSH requires operationId")
          RefusalLog.observe_envelope(env, source: "dispatcher", method: method)
          return env
        end
        if (cached = idempotency.get(opid))
          return Envelope.ok(id: id, result: Replay.from_first_result(cached), collection: false)
        end
      end

      value = op.handler.call(params, ctx)
      idempotency.put(opid, value) if op.direction == :push && !opid.empty?
      env = Envelope.ok(id: id, result: value, collection: op.result == :collection)
      RefusalLog.observe_envelope(env, source: "dispatcher", method: method, operation_id: opid)
      env
    rescue => e
      if defined?(::RailsOsiLevel8::KnownRefusal) && e.is_a?(::RailsOsiLevel8::KnownRefusal)
        raise
      end
      env = Envelope.fail(id: request["id"], reason: :handler_error, because: "#{e.class}: #{e.message}")
      RefusalLog.observe_envelope(env, source: "dispatcher", method: method, operation_id: opid)
      env
    end
  end
end
