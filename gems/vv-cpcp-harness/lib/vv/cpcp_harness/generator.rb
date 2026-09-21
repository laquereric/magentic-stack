# frozen_string_literal: true

module Vv
  module CpcpHarness
    # Direction A: a seam's published operations become tools.
    #
    # Generation reads the committed CID snapshot, so tool definitions are
    # reviewable in a pull request and builds are reproducible. Nothing
    # here is agent-specific: the same `Tool` reaches Claude Code and
    # OpenCode through their own adapters.
    module Generator
      module_function

      # Returns `{ ok: true, result: [Tool, ...], warnings: [...] }` or a
      # build-time refusal naming the first thing that did not line up.
      def tools_for(seam:, cid:, client:)
        included = Array(seam.include)
        included = cid.methods_published if included.empty?

        warnings = []
        tools = []

        included.each do |method|
          operation = cid.operation(method)
          if operation.nil?
            return Envelope.refuse(:operation_not_published,
                                   "#{seam.name}: #{method} is not in #{cid.source || "the CID"}; " \
                                   "published: #{cid.methods_published.join(", ")}")
          end

          face = cid.face_for(operation)
          return face unless face[:ok]

          built = tool_for(seam: seam, cid: cid, client: client,
                           operation: operation, face: face[:result])
          return built unless built[:ok]

          warnings.concat(built[:warnings] || [])
          tools << built[:result]
        end

        Envelope.ok(result: tools, warnings: warnings)
      end

      def tool_for(seam:, cid:, client:, operation:, face:)
        schema, schema_warnings, shape_name = schema_for(cid, operation)
        method = operation.method_name

        handler = lambda do |args, ctx|
          client.call(method: method, face: face, params: args,
                      operation_id: ctx.operation_id, rpc_id: ctx.rpc_id, iri: operation.iri)
        end

        built = Tool.define(
          name: tool_name(seam.name, method),
          description: description_for(cid, operation, face),
          schema: schema,
          seam: seam.name,
          method_name: method,
          cpcp: {
            iri: operation.iri,
            face: face,
            cid: { "url" => "#{seam.endpoint}/cid.json", "digest" => cid.digest },
            input_shape: shape_name
          },
          &handler
        )
        return built unless built[:ok]

        built.merge(warnings: schema_warnings.map { |w| "#{tool_name(seam.name, method)}: #{w}" })
      end

      # `note.create` on seam `back` becomes `back_note_create`. Each
      # adapter prefixes it in its own way; the identity that matters is
      # the IRI, which never reaches the model.
      def tool_name(seam_name, method)
        "#{seam_name}_#{method.tr(".", "_")}"
      end

      def description_for(cid, operation, face)
        parts = []
        parts << operation.description unless operation.description.to_s.empty?
        parts << cid.description unless cid.description.empty?
        parts << "Calls #{operation.method_name} on the #{cid.id || "seam"} contract."
        if face == :push
          parts << "Results describe an effect; a recording that is not yet applied says so."
        else
          parts << "Reads grounded context. It promises nothing about later state."
        end
        parts.join(" ").strip
      end

      # Shapes describe the payload, which for a PUSH is the params and
      # for a PULL is usually the result. The shape is used as the input
      # schema only where it actually describes the inputs; otherwise the
      # operation's informal params are the honest source.
      def schema_for(cid, operation)
        shapes = Shacl.parse(cid.shapes)
        keys = operation.params.is_a?(Hash) ? operation.params.keys.map(&:to_s) : []
        shape = shapes.find do |s|
          names = s.properties.map(&:name)
          !keys.empty? && (keys - names).empty?
        end

        if shape
          [Schema.from_shape(shape), shape.warnings, shape.name]
        else
          schema = Schema.from_params(operation.params)
          [schema, schema.warnings, nil]
        end
      end
    end
  end
end
