# frozen_string_literal: true
module RailsCpcp
  # Executes one operation call against the registry and returns a JSON-RPC-LD
  # response envelope. NEVER raises across the boundary.
  module Dispatcher
    module_function

    # AN operationId IDENTIFIES AN INTENT, NOT A ROW IN A SHARED NAMESPACE.
    #
    # The store was keyed on the operationId alone, so the same id used for two
    # DIFFERENT methods returned the first method's result -- with ok: true, as a
    # replay, and with nothing in the envelope to say the answer belonged to
    # another operation. Observed 2026-09-05: a check harness reused one id for
    # acia.publish and mind.derive; publish executed and stored, derive was handed
    # publish's receipt and never ran. Both looked successful.
    #
    # Callers do reuse ids. A request id, a job id, a correlation id -- all are
    # natural things to pass to more than one call, and the guarantee an
    # operationId is supposed to make is "this INTENT happens once", not "this
    # string is spent".
    #
    # RailsOsiLevel8's own replay lookup already keys on (operation_name, scope,
    # key) and was right; this layer runs first and was looser, so the loose one
    # decided. The two now agree.
    #
    # The separator is KEY_SEPARATOR below, with the reasoning beside it.
    #
    # NEVER FAILS THE CALL IT REPORTS ON (note_legacy_idempotency_hit below):
    # this is a note about bookkeeping, and a logger that is absent or raises
    # must not turn a correct replay into an error.
    def note_legacy_idempotency_hit(method, opid)
      line = { cpcp_legacy_idempotency_hit: { method: method, operation_id: opid } }
      if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
        ::Rails.logger.info(line.to_json)
      else
        warn line.to_json
      end
    rescue StandardError
      nil
    end

    # A NAMED CONSTANT, because the separator was invisible and I got it wrong.
    # The first version of this interpolated what looked like a space and was in
    # fact a NUL, so the comment described one character and the code used
    # another -- and an embedded NUL is a poor key for a SQLite TEXT column
    # besides, since it is exactly the byte C string handling truncates at.
    #
    # A space is unambiguous here because a method name cannot contain one: they
    # are registry keys like "acia.publish". The id may contain anything and
    # needs no constraint -- only the prefix has to read one way.
    KEY_SEPARATOR = " "

    def idempotency_key(method, opid)
      [method, opid].join(KEY_SEPARATOR)
    end

    # request: parsed hash { "method", "params", "id", "operationId" }
    # ctx: opaque per-request context handed to handlers (controller, current_user, ...)
    def call(request, ctx: nil, idempotency: RailsCpcp.idempotency_store, traceparent: nil)
      GenaiSpan.around(request: request, traceparent: traceparent) do
        dispatch(request, ctx: ctx, idempotency: idempotency)
      end
    end

    def dispatch(request, ctx: nil, idempotency: RailsCpcp.idempotency_store)
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
        # THE BARE KEY IS READ, NEVER WRITTEN. Receipts stored before this change
        # are keyed on the id alone, and a receipt must outlive the process that
        # issued it -- dropping the fallback would make a legitimate retry of an
        # older operationId EXECUTE A SECOND TIME, which is the failure this
        # store exists to prevent. Those keys are never added to, so the legacy
        # namespace only shrinks; while it is non-empty, an id reused across
        # methods and stored before this change can still cross over.
        scoped = idempotency_key(method, opid)
        if (cached = idempotency.get(scoped))
          return Envelope.ok(id: id, result: Replay.from_first_result(cached), collection: false)
        end

        if (cached = idempotency.get(opid))
          # SAY IT, AND MOVE IT. The fallback cannot be removed on a guess about
          # whether anything still needs it; this makes the answer observable --
          # a deployment logging none of these has an empty legacy namespace and
          # can drop the fallback safely.
          #
          # Copying the receipt to the scoped key retires that id: the next call
          # hits the line above, and one more entry stops being reachable by the
          # wrong method. The legacy row stays, because deleting evidence to tidy
          # a namespace is a worse trade than leaving it unread.
          note_legacy_idempotency_hit(method, opid)
          idempotency.put(scoped, cached)
          return Envelope.ok(id: id, result: Replay.from_first_result(cached), collection: false)
        end
      end

      value = op.handler.call(params, ctx)
      idempotency.put(idempotency_key(method, opid), value) if op.direction == :push && !opid.empty?
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
