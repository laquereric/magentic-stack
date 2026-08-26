# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"

module Mmg
  module Acia
    # Phase B — typed semantic state surface (epic_65 research §1).
    # Absence means unknown/N/A, not false. Known booleans must be explicit.
    module State
      PROFILE_VERSION = "1"
      ACIA_VOCAB = "urn:mm:vocab/acia#"
      ARIA_VOCAB = "urn:mm:vocab/aria#"

      # Registry: semantic_role (downcase) -> allowed state keys + RDF projection.
      REGISTRY = {
        "tab" => {
          keys: {
            "selected" => {
              type: :boolean,
              durable: true,
              rdf: "#{ARIA_VOCAB}selected",
              required_when_live: true
            },
            # Panel target IRI (aria:controls) — optional in storage; synthetic triples fill if absent
            "controls" => {
              type: :string,
              durable: true,
              rdf: "#{ARIA_VOCAB}controls",
              iri: true
            }
          }
        },
        "tablist" => {
          keys: {},
          # Selection is derived from child tabs — not stored on the list.
          derives_selection: true
        },
        "toggle" => {
          keys: {
            "pressed" => { type: :boolean, durable: true, rdf: "#{ARIA_VOCAB}pressed" },
            "checked" => { type: :boolean, durable: true, rdf: "#{ARIA_VOCAB}checked" },
            "expanded" => { type: :boolean, durable: true, rdf: "#{ARIA_VOCAB}expanded" }
          },
          # Exactly one of pressed|checked|expanded must be present when live.
          xor_presence: %w[pressed checked expanded]
        },
        "heading" => {
          keys: {
            "level" => {
              type: :integer,
              durable: true,
              rdf: "#{ARIA_VOCAB}level",
              min: 1,
              max: 6
            }
          }
        },
        "button" => {
          keys: {
            "pressed" => { type: :boolean, durable: true, rdf: "#{ARIA_VOCAB}pressed" }
          }
        },
        "image" => {
          keys: {
            "accessible_name" => {
              type: :string,
              durable: true,
              rdf: "#{ARIA_VOCAB}accessibleName",
              required_when_live: true
            }
          }
        }
      }.freeze

      module_function

      def profile_version = PROFILE_VERSION

      def registry_for(role)
        REGISTRY[role.to_s.strip.downcase]
      end

      def normalize(role, state)
        reg = registry_for(role)
        return { ok: true, state: {}, warnings: ["unknown_role"] } unless reg

        raw = coerce_hash(state)
        out = {}
        errors = []
        raw.each do |k, v|
          key = k.to_s
          spec = reg[:keys][key]
          unless spec
            errors << { path: key, message: "key not in registry for #{role}" }
            next
          end
          nv = coerce_value(v, spec)
          if nv[:ok]
            out[key] = nv[:value]
          else
            errors << { path: key, message: nv[:because] }
          end
        end

        if reg[:xor_presence]
          present = reg[:xor_presence].count { |k| !out[k].nil? }
          if present > 1
            errors << { path: "xor", message: "at most one of #{reg[:xor_presence].join('|')}" }
          end
        end

        {
          ok: errors.empty?,
          state: out,
          state_profile_version: PROFILE_VERSION,
          errors: errors,
          reason: (errors.empty? ? nil : :invalid_state)
        }
      rescue ::StandardError => e
        { ok: false, reason: :normalize_failed, because: "#{e.class}: #{e.message}", state: {}, errors: [] }
      end

      # Local topology + registry checks for a tree hash (before SHACL).
      def validate_tree(tree)
        issues = []
        walk(tree) do |node, path|
          role = (node[:semantic_role] || node["semantic_role"]).to_s
          st = node[:semantic_state] || node["semantic_state"] || {}
          norm = normalize(role, st)
          unless norm[:ok]
            issues.concat(norm[:errors].map { |e| e.merge(path: "#{path}/#{e[:path]}", entity_token: entity_token(node)) })
          end

          if role.downcase == "tab"
            sel = norm[:state]["selected"]
            if sel.nil?
              issues << {
                path: path,
                entity_token: entity_token(node),
                message: "tab requires explicit selected boolean",
                shape_id: "acia:TabShape"
              }
            end
          end

          if role.downcase == "tablist"
            tabs = children_of(node).select { |c| role_of(c) == "tab" }
            if tabs.empty?
              issues << {
                path: path,
                entity_token: entity_token(node),
                message: "tablist requires at least one tab child",
                shape_id: "acia:TabListShape"
              }
            else
              selected = tabs.count { |t| boolish(state_of(t)["selected"]) == true }
              if selected != 1
                issues << {
                  path: path,
                  entity_token: entity_token(node),
                  message: "tablist requires exactly one selected tab (got #{selected})",
                  shape_id: "acia:TabListShape"
                }
              end
            end
          end
        end
        {
          ok: true,
          conforms: issues.empty?,
          results: issues,
          profile: "acia_core_topology.v1"
        }
      rescue ::StandardError => e
        { ok: false, reason: :tree_validate_failed, because: "#{e.class}: #{e.message}" }
      end

      # Emit N-Triples for semantic state (subject IRI required).
      def state_triples(subject_iri, role, state)
        norm = normalize(role, state)
        return [] unless norm[:ok]

        triples = []
        triples << "<#{subject_iri}> <#{ACIA_VOCAB}stateProfileVersion> \"#{PROFILE_VERSION}\" ."
        reg = registry_for(role) || { keys: {} }
        norm[:state].each do |key, val|
          spec = reg[:keys][key]
          next unless spec
          pred = spec[:rdf]
          obj =
            if spec[:iri]
              "<#{val}>"
            else
              case spec[:type]
              when :boolean
                "\"#{val ? 'true' : 'false'}\"^^<http://www.w3.org/2001/XMLSchema#boolean>"
              when :integer
                "\"#{val}\"^^<http://www.w3.org/2001/XMLSchema#integer>"
              else
                "\"#{escape(val)}\""
              end
            end
          triples << "<#{subject_iri}> <#{pred}> #{obj} ."
        end
        # entity_token when present on state or separate
        et = norm[:state]["entity_token"]
        triples << "<#{subject_iri}> <#{ACIA_VOCAB}entityToken> \"#{escape(et)}\" ." if et
        triples
      end

      def parse_json(raw)
        return {} if raw.nil? || raw.to_s.empty?
        return raw if raw.is_a?(::Hash)
        ::JSON.parse(raw.to_s)
      rescue ::JSON::ParserError
        {}
      end

      def dump_json(state)
        ::JSON.generate(coerce_hash(state))
      end

      def coerce_hash(state)
        h = state.is_a?(::Hash) ? state : parse_json(state)
        h.transform_keys(&:to_s)
      end

      def coerce_value(v, spec)
        case spec[:type]
        when :boolean
          return { ok: false, because: "boolean required (absence != false)" } if v.nil?
          if v == true || v == false
            { ok: true, value: v }
          elsif %w[true false].include?(v.to_s.downcase)
            { ok: true, value: v.to_s.downcase == "true" }
          else
            { ok: false, because: "not a boolean" }
          end
        when :integer
          i = Integer(v)
          if spec[:min] && i < spec[:min]
            return { ok: false, because: "min #{spec[:min]}" }
          end
          if spec[:max] && i > spec[:max]
            return { ok: false, because: "max #{spec[:max]}" }
          end
          { ok: true, value: i }
        else
          s = v.to_s
          return { ok: false, because: "empty string" } if s.empty? && spec[:required_when_live]
          # IRI-valued strings: emit as resource in state_triples when spec[:iri]
          { ok: true, value: s }
        end
      rescue ::ArgumentError, ::TypeError
        { ok: false, because: "type mismatch for #{spec[:type]}" }
      end

      def walk(node, path = "$", &block)
        return unless node.is_a?(::Hash)
        yield node, path
        children_of(node).each_with_index do |child, i|
          walk(child, "#{path}/children[#{i}]", &block)
        end
      end

      def children_of(node)
        ::Kernel.Array(node[:children] || node["children"])
      end

      def role_of(node)
        (node[:semantic_role] || node["semantic_role"]).to_s.strip.downcase
      end

      def state_of(node)
        coerce_hash(node[:semantic_state] || node["semantic_state"])
      end

      def entity_token(node)
        (node[:entity_token] || node["entity_token"] ||
         node[:entity_iri] || node["entity_iri"]).to_s
      end

      def boolish(v)
        return true if v == true || v.to_s.downcase == "true"
        return false if v == false || v.to_s.downcase == "false"
        nil
      end

      def escape(v)
        v.to_s.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", "\\n")
      end

      private_class_method :coerce_hash, :coerce_value, :walk, :children_of,
                           :role_of, :state_of, :entity_token, :boolish, :escape
    end
  end
end
