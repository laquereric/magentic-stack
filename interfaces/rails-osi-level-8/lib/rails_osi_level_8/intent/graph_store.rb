# frozen_string_literal: true

require "json"
require "digest"

module RailsOsiLevel8
  module Intent
    # Append-only in-process + optional JSON file store for GRAPH-ONLY nodes
    # (IntentGrounding, IntentTrace, Job/Pain/Gain). Not an intent_groundings AR table.
    class GraphStore
      class << self
        def reset!
          @docs = {}
        end

        def put!(doc)
          doc = stringify(doc)
          cid = doc["cid"] || doc["@id"]
          raise ArgumentError, "cid required" if cid.to_s.empty?
          placement = doc["ledgerPlacement"] || doc["ledger_placement"] || "canonical"
          @docs ||= {}
          raise ArgumentError, "append-only: #{cid} exists" if @docs.key?(cid)
          @docs[cid] = doc.merge(
            "cid" => cid,
            "ledgerPlacement" => placement,
            "profileId" => doc["profileId"] || "osi-level-8/profile-10"
          )
          @docs[cid]
        end

        def get(cid)
          (@docs || {})[cid]
        end

        def find_by(type: nil, effect_cid: nil, journey_cid: nil, ledger: nil)
          (@docs || {}).values.select do |d|
            next false if type && d["@type"] != type
            next false if effect_cid && d["effectCid"] != effect_cid
            next false if journey_cid && d["journeyCid"] != journey_cid
            next false if ledger == "cross_boundary" && d["ledgerPlacement"] == "private_local"
            next false if ledger.is_a?(String) && ledger != "cross_boundary" && d["ledgerPlacement"] != ledger
            true
          end
        end

        def all_cross_boundary
          find_by(ledger: "cross_boundary")
        end

        def stringify(obj)
          case obj
          when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
          when Array then obj.map { |v| stringify(v) }
          else obj
          end
        end
      end
    end
  end
end
