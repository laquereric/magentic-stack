# frozen_string_literal: true

require "json"
require "fileutils"

module Vv
  module CpcpHarness
    # What the repo says it is, and what it says it calls (design §12),
    # plus the harness's own CID (§7.2).
    #
    # Both are generated from the configuration and the registry, so the
    # manifest cannot drift from what the agent can actually call. An
    # operation the harness wants but the seam does not publish yet is
    # recorded as `unbuilt` with a `because`, rather than discovered later
    # as an `unknown_operation` refusal.
    module Manifest
      CONTEXT = {
        "@vocab" => "https://w3id.org/cpcp/ns#",
        "id" => "@id",
        "type" => "@type",
        "operationId" => "https://w3id.org/json-rpc-ld/ns#operationId"
      }.freeze

      BINDING_BECAUSE = "in-process model-to-tool road; reasons proposed upstream, " \
                        "not yet in spec/refusals.md"

      module_function

      # `.cpcp/package.json`
      def package(config:, seams:, cid_path: "cpcp/harness.cid.json", examples: [])
        {
          "kind" => "cpcp-application",
          "version" => 1,
          "name" => config[:name],
          "contract" => {
            "repo" => config[:contract_repo],
            "rev" => config[:contract_rev]
          }.compact,
          "role" => { "name" => "FRONT", "of" => config[:unit] }.compact,
          "cids" => [{ "cid" => cid_path, "examples" => examples }],
          "scopes" => seams.map(&:scope_name).uniq,
          "bindings" => {
            "harness" => {
              "defined_by" => "docs/research/harness-cpcp-bridge-design.md",
              "because" => BINDING_BECAUSE,
              "reasons" => Reasons::BINDING.keys.map(&:to_s)
            }
          }
        }
      end

      # `.cpcp/<scope>/package.json`
      def scope(config:, seams:, scope: "dependency")
        {
          "kind" => "cpcp-scope",
          "scope" => scope,
          "depends_on" => seams.map { |seam| depends_on(seam) }
        }
      end

      def depends_on(seam, cid: nil)
        published = cid&.methods_published
        wanted = Array(seam.include)
        wanted = published || [] if wanted.empty?
        unbuilt = published ? wanted - published : []

        entry = {
          "producer" => seam.endpoint,
          "cid" => seam.cid_url,
          "operations" => wanted,
          "status" => unbuilt.empty? ? "published" : "unbuilt"
        }
        unless unbuilt.empty?
          entry["because"] = "the seam does not publish #{unbuilt.join(", ")} yet"
        end
        entry
      end

      # `cpcp/harness.cid.json` — one document describing everything the
      # agent can do natively, in the same vocabulary as the seams it
      # calls. It names a **binding**, not an endpoint: the harness serves
      # no `/_cpcp/rpc`, and the document says so rather than leaving a
      # reader to assume otherwise.
      def harness_cid(config:, tools:, example: nil)
        {
          "@context" => CONTEXT,
          "cid" => "cid:cpcp:#{config[:name]}:harness",
          "kind" => "binding",
          "binding" => "harness",
          "endpoint" => nil,
          "description" => "In-process tools the agent may call. This unit is a FRONT: it serves " \
                           "no CPCP seam, and these operations are reached through the harness's " \
                           "execute() wrapper, not over HTTP.",
          "operations" => tools.map { |tool| operation(tool) },
          "example_caller" => example || "spec/conformance_spec.rb"
        }
      end

      def operation(tool)
        {
          "method" => tool.method_name || tool.name,
          "iri" => tool.iri,
          "face" => tool.face.to_s,
          "params" => tool.schema.json_schema["properties"].keys,
          "operationId" => tool.push? ? "minted by the harness when absent" : nil,
          "result" => tool.cpcp&.output_shape || "envelope",
          "durable_replay" => tool.push? ? false : nil
        }.compact
      end

      # Write the manifest files a CI check reads.
      def write(dir:, bridge:, examples: [])
        cid_path = File.join(dir, "cpcp", "harness.cid.json")
        FileUtils.mkdir_p(File.join(dir, ".cpcp"))
        FileUtils.mkdir_p(File.dirname(cid_path))

        written = {}
        written[File.join(dir, ".cpcp", "package.json")] =
          package(config: bridge.config, seams: bridge.config.seams, examples: examples)

        bridge.config.seams.group_by(&:scope_name).each do |scope_name, seams|
          FileUtils.mkdir_p(File.join(dir, ".cpcp", scope_name))
          written[File.join(dir, ".cpcp", scope_name, "package.json")] = {
            "kind" => "cpcp-scope",
            "scope" => scope_name,
            "depends_on" => seams.map { |seam| depends_on(seam, cid: bridge.cids[seam.name]) }
          }
        end

        written[cid_path] = bridge.harness_cid

        written.each { |path, payload| File.write(path, "#{JSON.pretty_generate(payload)}\n") }
        Envelope.ok(result: written.keys)
      rescue StandardError => e
        Envelope.refuse(:cid_unreadable, "#{e.class}: #{e.message}")
      end
    end
  end
end
