# frozen_string_literal: true

require "timeout"

module Vv
  module CpcpHarness
    # Who is calling, and on whose word. Carried beside every execution
    # and copied into the journal.
    # `auth_mode` is the kind of credential the backend used — `api_key`,
    # `cloud` or `subscription` — never the credential. "On whose word"
    # is incomplete without which account paid for the call.
    Context = Struct.new(:session_id, :backend, :model, :agent, :rpc_id,
                         :approved_by, :operation_id, :auth_mode, keyword_init: true)

    # The one way a tool reaches the world.
    #
    # Everything that must happen on every call happens here, once: the
    # local schema check, the `operationId`, the permission decision, the
    # receipt replay, the envelope, the journal line, the rendering. A
    # second path to a handler would be a second set of rules.
    class Registry
      attr_reader :journal, :permissions, :receipts

      def initialize(permissions: nil, journal: nil, receipts: nil, ledger: nil)
        @tools = {}
        @iris = {}
        @permissions = permissions || Permissions.new
        @journal = journal || Journal.new
        @receipts = receipts || Receipts::NullStore.new
        @ledger = ledger || OperationId::Ledger.new
      end

      # Accepts a Tool or the envelope `Tool.define` returns.
      def register(tool)
        tool = tool[:result] if tool.is_a?(Hash) && tool.key?(:ok)
        return Envelope.refuse(:tool_definition_invalid, "not a tool: #{tool.class}") unless tool.is_a?(Tool)

        if @tools.key?(tool.name)
          return Envelope.refuse(:tool_name_taken, "#{tool.name} is already registered")
        end
        if tool.iri && @iris.key?(tool.iri)
          return Envelope.refuse(:iri_taken, "#{tool.iri} is already claimed by #{@iris[tool.iri]}")
        end

        @tools[tool.name] = tool
        @iris[tool.iri] = tool.name if tool.iri
        Envelope.ok(result: tool)
      end

      def register_all(tools)
        Array(tools).each do |tool|
          res = register(tool)
          return res unless res[:ok]
        end
        Envelope.ok(result: self.tools)
      end

      def tools
        @tools.values
      end

      def tool(name)
        @tools[name.to_s]
      end

      def tool_by_iri(iri)
        @tools[@iris[iri]]
      end

      # Run one tool call and return what the model should see.
      def execute(name, args = {}, context: nil, warnings: [])
        context ||= Context.new
        tool = @tools[name.to_s]
        unless tool
          return render(nil, Envelope.refuse(:unknown_operation, "no tool named #{name}"), warnings)
        end

        args = normalize(args)
        # The id is minted before anything can fail, so that every result
        # — including a refusal — can name the write the model asked for.
        operation_id, source = operation_id_for(tool, args)
        notes = Array(warnings)

        problem = tool.schema.validate(args)
        if problem
          return finish(tool, Envelope.refuse(:harness_input_rejected, problem, operation_id: operation_id),
                        operation_id, source, context, notes)
        end

        gate = gate(tool, args, operation_id, context)
        context = context.dup
        context.approved_by = gate.approved_by if gate.approved_by
        return finish(tool, gate.refusal, operation_id, source, context, notes) if gate.refusal

        replay = replay_for(tool, operation_id)
        notes += Array(Receipts::WARNINGS[replay.warning]) if replay&.warning
        if replay&.hit?
          return finish(tool, replay.envelope.merge(replayed: true), operation_id, source, context, notes)
        end

        envelope = run(tool, args, operation_id, context)
        envelope = envelope.merge(operation_id: operation_id) if operation_id && !envelope[:operation_id]
        notes += Array(envelope[:warnings])
        notes += store_receipt(tool, operation_id, envelope)

        finish(tool, envelope, operation_id, source, context, notes)
      end

      # The `tool_result` event a runner emits (design §9.5).
      def event(rendered, call_id: nil, backend: nil)
        {
          type: "tool_result",
          id: call_id,
          tool: rendered[:tool],
          backend: backend,
          output: Render.open_code(rendered),
          is_error: !rendered[:ok],
          iri: rendered[:iri],
          operation_id: rendered[:operation_id],
          reason: rendered[:reason]&.to_s,
          failure_layer: rendered[:failure_layer]&.to_s
        }.reject { |_, v| v.nil? }
      end

      private

      def normalize(args)
        return args unless args.is_a?(Hash)

        args.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
      end

      # Minted once per tool call, reused by every transport-level retry
      # of that call, and returned in every result.
      def operation_id_for(tool, args)
        return [nil, nil] unless tool.push?

        given = args.is_a?(Hash) ? (args["operationId"] || args["operation_id"]) : nil
        return [given.to_s, :model] unless given.to_s.empty?

        [OperationId.mint(tool.method_name || tool.name), :minted]
      end

      Gate = Struct.new(:refusal, :approved_by, keyword_init: true)

      # Permission, then the id ledger. A refusal here means the call must
      # not proceed; the human's name, when there is one, rides along to
      # the journal.
      def gate(tool, args, operation_id, context)
        decision = @permissions.decide(tool)
        approved_by = nil

        case decision.action
        when :deny
          return Gate.new(refusal: Envelope.refuse(
            :user_declined, "the harness's permission policy denies this operation",
            operation_id: operation_id, iri: tool.iri, seam: tool.seam
          ))
        when :ask
          answer = @permissions.approve(tool: tool, args: args, operation_id: operation_id,
                                        context: context)
          unless answer[:approved]
            return Gate.new(refusal: Envelope.refuse(
              :user_declined, answer[:because],
              operation_id: operation_id, iri: tool.iri, seam: tool.seam
            ))
          end

          approved_by = answer[:by]
        end

        conflict = @ledger.check(operation_id, args.reject { |k, _| %w[operationId operation_id].include?(k) })
        return Gate.new(approved_by: approved_by) if conflict.nil?

        Gate.new(approved_by: approved_by, refusal: Envelope.refuse(
          :harness_input_rejected, conflict, operation_id: operation_id, iri: tool.iri
        ))
      end

      # Only native PUSH tools replay here. A seam's own idempotency store
      # is authoritative for Direction A, and asking twice on this side
      # would hide a receipt the seam wants to hand back.
      def replay_for(tool, operation_id)
        return nil unless tool.native? && tool.push? && operation_id

        @receipts.fetch(tool.iri, operation_id)
      end

      def store_receipt(tool, operation_id, envelope)
        return [] unless tool.native? && tool.push? && operation_id && envelope[:ok]

        warning = @receipts.store(tool.iri, operation_id, envelope)
        Array(Receipts::WARNINGS[warning])
      end

      def run(tool, args, operation_id, context)
        call_context = context.dup
        call_context.operation_id = operation_id

        result =
          if tool.timeout
            Timeout.timeout(tool.timeout) { tool.handler&.call(args, call_context) }
          else
            tool.handler&.call(args, call_context)
          end

        coerce(tool, result)
      rescue Timeout::Error
        Envelope.refuse(:harness_timeout, "#{tool.name} exceeded #{tool.timeout}s")
      rescue StandardError => e
        # A handler never throws across the boundary. If it does, the
        # boundary holds and the throw becomes data.
        Envelope.refuse(:harness_tool_refused, "#{e.class}: #{e.message}", failure_layer: :infrastructure)
      end

      # A native handler may answer in Doc 1's shapes; a generated seam
      # handler already answers with an envelope.
      def coerce(tool, result)
        case result
        when nil then Envelope.ok(result: nil)
        when String then Envelope.ok(result: nil, text: result)
        when Hash
          return result if result.key?(:ok)

          coerce_hash(tool, result.transform_keys(&:to_sym))
        else Envelope.ok(result: result)
        end
      end

      def coerce_hash(tool, result)
        if result.key?(:error)
          reason = result[:reason]
          unless Reasons.allowed?(reason&.to_s&.to_sym)
            # Logged, not passed through: an unregistered reason read as
            # a stable one would be a promise the contract never made.
            result = result.merge(
              error: [result[:error], reason && "(unregistered reason #{reason})"].compact.join(" ")
            )
            reason = :harness_tool_refused
          end
          return Envelope.refuse(reason, [result[:error], result[:hint]].compact.join(" — "),
                                 ld: result[:ld], iri: tool.iri)
        end

        ld = result[:ld] || result[:json]
        Envelope.ok(result: ld, text: result[:text], ld: ld, iri: tool.iri)
      end

      # Journal the call, then render it. Every exit from `execute` goes
      # through here, so no path can quietly skip the record.
      def finish(tool, envelope, operation_id, source, context, notes)
        journal_call(tool, envelope, operation_id, source, context)
        render(tool, envelope, notes)
      end

      def journal_call(tool, envelope, operation_id, source, context)
        if tool.push?
          @journal.push(tool: tool, envelope: envelope, operation_id: operation_id,
                        operation_id_source: source, context: context)
        else
          @journal.pull(tool: tool, envelope: envelope, context: context)
        end
      end

      def render(tool, envelope, warnings)
        Render.result(envelope, tool: tool, warnings: warnings.compact.uniq)
              .merge(tool: tool&.name).reject { |_, v| v.nil? }
      end
    end
  end
end
