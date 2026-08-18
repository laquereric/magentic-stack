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
      op = Registry.find(method)
      return Envelope.fail(id: id, reason: :unknown_operation, because: "no CPCP operation #{method.inspect}") unless op

      missing = op.params - params.keys
      return Envelope.fail(id: id, reason: :missing_params, because: "missing #{missing.join(', ')}") unless missing.empty?

      opid = (request["operationId"] || params["operationId"]).to_s
      if op.direction == :push
        return Envelope.fail(id: id, reason: :operation_id_required, because: "PUSH requires operationId") if opid.empty?
        if (cached = idempotency.get(opid))
          return Envelope.ok(id: id, result: cached, collection: op.result == :collection)
        end
      end

      value = op.handler.call(params, ctx)
      idempotency.put(opid, value) if op.direction == :push && !opid.empty?
      Envelope.ok(id: id, result: value, collection: op.result == :collection)
    rescue => e
      Envelope.fail(id: request["id"], reason: :handler_error, because: "#{e.class}: #{e.message}")
    end
  end
end
