# frozen_string_literal: true

module Mmg
  module Switchyard
    # Switchyard client — threedot LLM-assistance plane for Develop + RUN.
    # Flow: Config -> Router.choose -> Contract.validate_request ->
    #       optional translate -> Source adapter (stub; Switchyard HTTP pre-alpha) ->
    #       Contract.validate_response -> Observe.span -> never-raise envelope.
    # Doctrine: CID + policy MM-owned; Switchyard is routing plane ONLY.
    class Client
      attr_reader :config, :local_source, :remote_source

      def initialize(config, local_source: nil, remote_source: nil)
        @config = config
        @local_source = local_source || Adapters::LocalSource.new
        @remote_source = remote_source || Adapters::RemoteSource.new
      end

      def assist(request, ctx: nil)
        Observe.span("switchyard.assist", config: @config) do
          assist_inner(request, ctx: ctx)
        end
      rescue StandardError => e
        Outcome.fail(reason: :assist_error, because: "#{e.class}: #{e.message}")
      end

      private

      def assist_inner(request, ctx: nil)
        route = Router.choose(@config)
        # freeze route onto a shallow copy so Observe attrs see it
        @config = Config.new(**@config.to_h.merge(route: route, source: route))

        vr = Contract.validate_request(@config, request)
        return vr unless vr[:ok]

        normalized = vr[:value]
        target_fmt = (@config.format || :openai).to_sym
        tr = Router.translate(normalized, to: target_fmt)
        return tr unless tr[:ok]

        payload = tr[:value]
        source = route == :remote ? @remote_source : @local_source

        raw =
          begin
            source.call(@config, payload)
          rescue StandardError => e
            return Outcome.fail(reason: :source_error, because: "#{e.class}: #{e.message}", meta: { route: route })
          end

        # Adapter may return Outcome already
        if raw.is_a?(Hash) && raw.key?(:ok)
          return raw unless raw[:ok]

          raw = raw[:value]
        end

        vres = Contract.validate_response(@config, raw)
        return vres unless vres[:ok]

        Outcome.ok(
          value: {
            response: vres[:value],
            route: route,
            cid_iri: @config.cid_iri,
            model: @config.model,
            format: target_fmt.to_s
          },
          reason: :assisted,
          meta: { ctx_present: !ctx.nil?, source_class: source.class.name }
        )
      end
    end
  end
end
