# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"
require "digest"
require "securerandom"
require "time"
require_relative "state"
require_relative "transition"

module Mmg
  module Acia
    # Phase B — ValidatedSnapshot capability object (research §2.1).
    # deliver_tree! / SAL / A2A should require this when enforce: true.
    module ValidatedSnapshot
      SCHEMA = "AciaValidatedSnapshot.v1"
      ENFORCING_PROFILE = "acia_core_enforcing"
      ADVISORY_PROFILE = "acia_advisory"

      module_function

      # Build from a render-tree hash. Topology always; SHACL when available.
      def from_tree(tree, enforce: true, tree_key: nil, shacl: true)
        return refused(:invalid_tree, "tree must be a Hash") unless tree.is_a?(::Hash)

        topo = State.validate_tree(tree)
        return topo.merge(ok: false, reason: :topology_failed) unless topo[:ok]

        shacl_report = nil
        if shacl && shapes_available?
          triples = synthetic_triples(tree)
          shacl_report = ::Mmg::Acia::Shapes.validate(triples)
        end

        shacl_conforms =
          if shacl_report.nil?
            true # no engine → topology-only gate
          elsif shacl_report[:ok] == false && shacl_report[:reason] == :shacl_unavailable
            true
          elsif shacl_report[:ok] == false
            false
          else
            shacl_report[:conforms] == true
          end

        conforms = topo[:conforms] == true && shacl_conforms
        rev = Transition.tree_revision(tree)
        correlation_id = "val_#{::SecureRandom.hex(6)}"

        results = ::Kernel.Array(topo[:results])
        if shacl_report.is_a?(::Hash) && shacl_report[:ok] && shacl_report[:results]
          results += ::Kernel.Array(shacl_report[:results]).map { |r| normalize_shacl_result(r) }
        elsif shacl_report.is_a?(::Hash) && shacl_report[:ok] == false &&
              shacl_report[:reason] != :shacl_unavailable
          results << { message: shacl_report[:because], severity: "Violation", shape_id: "shacl_engine" }
          conforms = false if enforce
        end

        snapshot = {
          "schema" => SCHEMA,
          "profile" => enforce ? ENFORCING_PROFILE : ADVISORY_PROFILE,
          "tree_key" => tree_key,
          "tree_revision" => rev,
          "state_profile_version" => State::PROFILE_VERSION,
          "conforms" => conforms,
          "correlation_id" => correlation_id,
          "topology" => topo,
          "shacl" => shacl_report,
          "results" => results,
          "tree" => tree,
          "validated_at" => ::Time.now.utc.iso8601
        }

        if enforce && !conforms
          {
            ok: false,
            reason: :validation_failed,
            because: "candidate does not conform (#{results.size} issue(s))",
            snapshot: snapshot,
            conforms: false,
            results: results,
            correlation_id: correlation_id
          }
        else
          {
            ok: true,
            snapshot: snapshot,
            conforms: conforms,
            tree_revision: rev,
            correlation_id: correlation_id,
            results: results
          }
        end
      rescue ::StandardError => e
        refused(:snapshot_failed, "#{e.class}: #{e.message}")
      end

      # Apply select_tab then validate (full Phase-B vertical slice).
      def select_and_validate(tree, entity_token:, expected_revision: nil, enforce: true)
        tr = Transition.select_tab(tree, entity_token: entity_token, expected_revision: expected_revision)
        return tr unless tr[:ok]
        from_tree(tr[:candidate], enforce: enforce).merge(
          transition: tr,
          action: "select",
          entity_token: entity_token.to_s
        )
      end

      def shapes_available?
        return false unless defined?(::Mmg::Acia::Shapes)
        ::Mmg::Acia::Shapes.respond_to?(:validate)
      rescue ::StandardError
        false
      end

      # Minimal N-Triples for SHACL when Node AR is unavailable (pure tree path).
      def synthetic_triples(tree)
        rows = []
        walk = lambda do |node, idx_path|
          return unless node.is_a?(::Hash)
          role = (node[:semantic_role] || node["semantic_role"]).to_s.strip.downcase
          token = State.send(:entity_token, node)
          subj = token.empty? ? "urn:mm:acia:anon:#{idx_path}" : token
          subj = "urn:mm:acia:node:#{::Digest::SHA256.hexdigest(subj)[0, 12]}" unless subj.start_with?("urn:")
          role_iri = ::Mmg::Acia::Node::ROLE_IRI.fetch(role, ::Mmg::Acia::Node::DEFAULT_ROLE_IRI) rescue "#{State::ACIA_VOCAB}Node"
          # Prefer local constants when Node not loaded
          role_iri = case role
                     when "tab" then "#{State::ACIA_VOCAB}Tab"
                     when "tablist" then "#{State::ACIA_VOCAB}TabList"
                     when "toggle" then "#{State::ACIA_VOCAB}Toggle"
                     when "button" then "#{State::ACIA_VOCAB}Button"
                     when "heading" then "#{State::ACIA_VOCAB}Heading"
                     when "image" then "#{State::ACIA_VOCAB}Image"
                     else "#{State::ACIA_VOCAB}Node"
                     end
          rows << "<#{subj}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#{role_iri}> ."
          name = (node[:value] || node["value"]).to_s
          unless name.empty?
            rows << "<#{subj}> <#{State::ARIA_VOCAB}accessibleName> \"#{State.send(:escape, name)}\" ."
          end
          st = State.send(:state_of, node)
          rows.concat(State.state_triples(subj, role, st))
          # Tab: aria:controls placeholder if missing (controls panel IRI)
          if role == "tab"
            controls = st["controls"] || "#{subj}:panel"
            rows << "<#{subj}> <#{State::ARIA_VOCAB}controls> <#{controls}> ." unless rows.any? { |t| t.include?("controls") }
          end
          # child links for tablist
          kids = State.send(:children_of, node)
          kids.each_with_index do |child, i|
            ctok = State.send(:entity_token, child)
            csubj = ctok.empty? ? "urn:mm:acia:anon:#{idx_path}.#{i}" : ctok
            csubj = "urn:mm:acia:node:#{::Digest::SHA256.hexdigest(csubj)[0, 12]}" unless csubj.start_with?("urn:")
            rows << "<#{subj}> <#{State::ACIA_VOCAB}hasChild> <#{csubj}> ." if role == "tablist"
            walk.call(child, "#{idx_path}.#{i}")
          end
        end
        walk.call(tree, "0")
        rows
      end

      def normalize_shacl_result(r)
        return r if r.is_a?(::Hash)
        { message: r.to_s, severity: "Violation" }
      end

      def refused(reason, because)
        { ok: false, reason: reason, because: because.to_s }
      end

      private_class_method :shapes_available?, :synthetic_triples, :normalize_shacl_result, :refused
    end
  end
end
