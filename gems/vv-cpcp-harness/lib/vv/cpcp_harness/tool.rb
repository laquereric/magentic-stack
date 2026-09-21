# frozen_string_literal: true

module Vv
  module CpcpHarness
    # One tool the model can call: a seam operation generated from a CID
    # (Direction A) or a native handler that opted into CPCP's discipline
    # (Direction B). Both kinds reach the model the same way and reach the
    # world only through `Registry#execute`.
    class Tool
      # What a grounded tool claims about itself. The IRI, not the tool
      # name, is what logs, the journal and permission rules key off.
      Cpcp = Struct.new(:iri, :face, :cid, :input_shape, :output_shape, keyword_init: true) do
        def push? = face.to_s == "push"
        def pull? = face.to_s == "pull"
      end

      # Generated onto every PUSH description. The model, not the harness,
      # decides whether to try again, and a second tool call is a new call
      # — without this sentence it would mint a new id and write twice.
      RETRY_SENTENCE = "To retry the same write after an error or timeout, pass the operationId " \
                       "from the earlier result. Omit it only for a new, separate write."

      attr_reader :name, :description, :schema, :handler, :cpcp, :seam, :method_name, :timeout

      def initialize(name:, description: "", schema: nil, handler: nil, cpcp: nil,
                     read_only: nil, seam: nil, method_name: nil, timeout: nil)
        @name = name.to_s
        @description = description.to_s
        @schema = schema || Schema.permissive
        @handler = handler
        @cpcp = cpcp
        @read_only = read_only
        @seam = seam
        @method_name = method_name
        @timeout = timeout
      end

      class << self
        # Build a tool, enforcing what `defineTool` enforces when a `cpcp`
        # block is present (design §9.1). Never raises: a bad definition
        # is a build-time refusal.
        def define(name:, description: "", schema: nil, cpcp: nil, read_only: nil,
                   seam: nil, method_name: nil, timeout: nil, &handler)
          info = coerce_cpcp(cpcp)
          return info unless info.nil? || info.is_a?(Cpcp)

          if info&.push? && read_only == true
            return Envelope.refuse(:tool_definition_invalid,
                                   "#{name}: a PUSH tool cannot be read-only")
          end

          schema ||= Schema.permissive
          schema = schema.with_operation_id if info&.push?
          text = description.to_s
          text = "#{text}\n\n#{RETRY_SENTENCE}".strip if info&.push?
          text = "#{text}\n\nFace: #{info.face} (#{info.push? ? "writes" : "reads"}).".strip if info

          Envelope.ok(result: new(
            name: name, description: text, schema: schema, cpcp: info, handler: handler,
            read_only: read_only.nil? ? !info&.push? : read_only,
            seam: seam, method_name: method_name, timeout: timeout
          ))
        end

        def coerce_cpcp(cpcp)
          return nil if cpcp.nil?
          return cpcp if cpcp.is_a?(Cpcp)

          unless cpcp.is_a?(Hash)
            return Envelope.refuse(:tool_definition_invalid, "cpcp must be a hash, got #{cpcp.class}")
          end

          known = cpcp.transform_keys(&:to_sym).slice(*Cpcp.members)
          info = Cpcp.new(**known)
          unless %w[pull push].include?(info.face.to_s)
            return Envelope.refuse(:tool_definition_invalid,
                                   "face must be pull or push, got #{info.face.inspect}")
          end
          if info.iri.to_s.empty?
            return Envelope.refuse(:tool_definition_invalid, "a grounded tool needs an operation IRI")
          end

          info
        end
      end

      def iri
        @cpcp&.iri
      end

      def face
        @cpcp&.face&.to_sym
      end

      def push?
        face == :push
      end

      def pull?
        face == :pull
      end

      def read_only?
        @read_only == true
      end

      # Direction A tools carry a seam; Direction B tools run in-process.
      def native?
        @seam.nil?
      end

      def to_h
        {
          name: @name,
          description: @description,
          input_schema: @schema.json_schema,
          read_only: read_only?,
          cpcp: @cpcp && { iri: @cpcp.iri, face: @cpcp.face.to_s, cid: @cpcp.cid,
                           input_shape: @cpcp.input_shape, output_shape: @cpcp.output_shape }.compact
        }.compact
      end
    end
  end
end
