# frozen_string_literal: true

module Vv
  module CpcpHarness
    # The bridge itself: seams in, tools out, one registry through which
    # every call passes.
    #
    #   bridge = Vv::CpcpHarness.bridge(seams: [...])[:result]
    #   bridge.execute("back_note_list")
    #
    # In CPCP terms what this builds is a FRONT. It calls seams and serves
    # none: there is no `/_cpcp/rpc` here, and a harness that shared a
    # container with a BACK it calls would not be a conformant
    # deployment, because a native tool could then reach domain state
    # without crossing the seam.
    class Bridge
      attr_reader :config, :registry, :clients, :cids, :warnings

      def initialize(config:, registry:, clients:, cids:, warnings: [])
        @config = config
        @registry = registry
        @clients = clients
        @cids = cids
        @warnings = warnings
      end

      class << self
        # `transport_factory` takes a Seam and returns a transport; specs
        # pass a fake and never touch the network.
        def build(config, transport_factory: nil, clock: nil, sleeper: nil)
          config = config[:result] if config.is_a?(Hash) && config.key?(:ok)

          registry = Registry.new(
            permissions: Permissions.new(rules: config[:permission_rules], approver: config[:approver]),
            journal: Journal.new(path: config[:journal_path], sink: config[:journal_sink],
                                 pull_sample: config[:pull_sample], clock: clock),
            receipts: receipts_for(config)
          )

          clients = {}
          cids = {}
          warnings = []

          config.seams.each do |seam|
            loaded = load_cid(seam)
            return loaded unless loaded[:ok]

            cid = loaded[:result]
            if seam.cid_digest && seam.cid_digest != cid.digest
              return Envelope.refuse(:snapshot_digest_mismatch,
                                     "#{seam.name}: snapshot digests #{cid.digest}, pinned #{seam.cid_digest}")
            end

            client = Client.new(
              seam: seam.name,
              transport: (transport_factory || method(:default_transport)).call(seam),
              cid: cid,
              contract_version: seam.contract_version,
              pin_ttl: seam.pin_ttl || config[:pin_ttl],
              clock: clock,
              sleeper: sleeper
            )

            generated = Generator.tools_for(seam: seam, cid: cid, client: client)
            return generated unless generated[:ok]

            registered = registry.register_all(generated[:result])
            return registered unless registered[:ok]

            warnings.concat(generated[:warnings] || [])
            clients[seam.name] = client
            cids[seam.name] = cid
          end

          Envelope.ok(result: new(config: config, registry: registry, clients: clients,
                                  cids: cids, warnings: warnings))
        end

        def load_cid(seam)
          return Cid.from(seam.cid_payload, source: "#{seam.name} (inline)") if seam.cid_payload

          Cid.load(seam.cid_snapshot)
        end

        def receipts_for(config)
          return config[:receipts] if config[:receipts]

          dir = config[:receipts_dir]
          dir ? Receipts::FileStore.new(dir) : Receipts::NullStore.new
        end

        def default_transport(seam)
          Transport.new(
            endpoint: seam.endpoint,
            credential: seam.credential,
            status_profile: seam.status_profile,
            read_timeout: seam.timeout || Transport::DEFAULT_READ_TIMEOUT
          )
        end
      end

      def tools
        @registry.tools
      end

      def tool(name)
        @registry.tool(name)
      end

      def execute(name, args = {}, context: nil)
        @registry.execute(name, args, context: context)
      end

      # Direction B: a native tool that opted into CPCP's discipline.
      # Still in-process; nothing is served over HTTP.
      def ground(name:, description: "", schema: nil, cpcp: nil, timeout: nil, read_only: nil, &handler)
        tool = Tool.define(name: name, description: description, schema: schema, cpcp: cpcp,
                           timeout: timeout, read_only: read_only, &handler)
        return tool unless tool[:ok]

        registered = @registry.register(tool[:result])
        return registered unless registered[:ok]

        tool
      end

      # The MCP road (see `Mcp`). The same registry, served to a client
      # that brings its own model and its own credential — the way
      # through when the in-process path is closed.
      #
      #   Vv::CpcpHarness::Mcp::Stdio.new(server: bridge.mcp_server).run
      def mcp_server(**options)
        Mcp::Server.new(bridge: self, **options)
      end

      # What this run is about to spend, and against whose account
      # (design §10.1).
      #
      # Two credentials matter and they are not the same. The seam
      # credentials below are the deployment's, and this gem holds them.
      # `auth` describes the one that pays for the model, which belongs
      # to a person or an organization and which this gem never holds —
      # the backend passes in what it used, and the harness prints it.
      #
      # Nothing here reads a credential's value beyond asking whether
      # there is one.
      def preflight(auth: nil, shared: false)
        seams = @config.seams.map do |seam|
          credential = seam.credential
          {
            "seam" => seam.name,
            "endpoint" => seam.endpoint,
            "source" => (credential.source if credential.respond_to?(:source)) || "an opaque callable",
            "present" => credential.respond_to?(:present?) ? credential.present? : !credential.nil?,
            "operations" => Array(seam.include),
            "scope" => seam.scope_name
          }
        end

        report = {
          "harness" => @config[:name],
          "role" => "FRONT",
          "shared_run" => shared,
          "model_credential" => auth&.to_h,
          "environment_hints" => Auth.env_hints.map { |h| "#{h[:mode]} from #{h[:source]}" },
          "seams" => seams
        }

        refusal = auth&.check(shared: shared)
        return refusal.merge(report: report) if refusal

        if auth.nil? && shared
          return Envelope.refuse(:auth_mode_not_permitted,
                                 "a shared or scheduled run must declare how its backend authenticates")
                         .merge(report: report)
        end

        Envelope.ok(result: report)
      end

      # The preflight as lines a human reads. Never a credential value.
      def preflight_lines(auth: nil, shared: false)
        result = preflight(auth: auth, shared: shared)
        report = result[:ok] ? result[:result] : result[:report]

        lines = ["#{report["harness"]} (FRONT)#{report["shared_run"] ? ", shared run" : ""}"]
        lines << "model: #{auth.describe}" if auth
        if auth && !auth.attests_account?
          lines << "attribution: the calling client authenticates for itself; " \
                   "this harness cannot say which account paid"
        end
        report["environment_hints"].each { |hint| lines << "environment: #{hint} — this outranks a plan login" }
        report["seams"].each do |seam|
          lines << "seam #{seam["seam"]}: credential #{seam["source"]}" \
                   "#{seam["present"] ? "" : " (MISSING)"}, #{seam["operations"].length} operations"
        end
        lines << "refused: #{Envelope.text(result[:because])}" unless result[:ok]
        lines
      end

      # Is each seam still serving the contract its snapshot pinned?
      # This is what CI runs: a stale snapshot fails the build instead of
      # surfacing later as a refusal in front of a model.
      def sync
        problems = @clients.filter_map do |name, client|
          refusal = client.check_pin(force: true)
          next nil unless refusal

          "#{name}: #{Envelope.text(refusal[:because])}"
        end
        return Envelope.refuse(:contract_superseded, problems.join("; ")) unless problems.empty?

        Envelope.ok(result: @clients.keys)
      end

      # The repo manifest and the harness's own CID (design §7.2, §12).
      def manifest
        Manifest.package(config: @config, seams: @config.seams)
      end

      def dependency_manifest(scope = "dependency")
        seams = @config.seams.select { |s| s.scope_name == scope }
        {
          "kind" => "cpcp-scope",
          "scope" => scope,
          "depends_on" => seams.map { |seam| Manifest.depends_on(seam, cid: @cids[seam.name]) }
        }
      end

      def harness_cid
        Manifest.harness_cid(config: @config, tools: tools.select(&:native?))
      end
    end
  end
end
