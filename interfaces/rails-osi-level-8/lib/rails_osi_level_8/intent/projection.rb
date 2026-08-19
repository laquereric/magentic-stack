# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Intent
    # P10.M1 — read-only projection adapter. Derives deterministic P10 CIDs from
    # canonical AR homes without duplicating them into intent_* tables.
    module Projection
      PROFILE_ID = "osi-level-8/profile-10"
      TYPE_MAP = {
        "Mission" => "intent:Mission",
        "Vision" => "intent:Vision",
        "Persona" => "intent:Persona",
        "Actor" => "intent:Actor",
        "Journey" => "c4:Journey",
        "Flow" => "ux:Flow"
      }.freeze

      module_function

      def for(record)
        raise ArgumentError, "record required" unless record

        klass = record.class.name
        type = TYPE_MAP.fetch(klass) { raise ArgumentError, "no P10 projection for #{klass}" }

        intrinsic = intrinsic_payload(record)
        digest = Digest::SHA256.hexdigest(canonical_json(intrinsic))
        cid = "cid:sha256:#{Digest::SHA256.hexdigest("#{klass}:#{record.id}:#{digest}")}"

        {
          "@id" => cid,
          "@type" => type,
          "cid" => cid,
          "profileId" => PROFILE_ID,
          "sourceClass" => klass,
          "sourceId" => record.id,
          "digest" => "sha256:#{digest}",
          "ledgerPlacement" => default_placement(record),
          "state" => record.try(:status) || "active",
          "title" => record.try(:title) || record.try(:name),
          "body" => record.try(:body) || record.try(:summary) || record.try(:goal) || record.try(:task_goal),
          "created" => record.try(:created_at)&.iso8601
        }
      end

      def print_demo!(io = $stdout)
        samples = []
        samples << ["Mission", defined?(::Mission) ? ::Mission.order(:id).first : nil]
        samples << ["Persona", defined?(::Persona) ? ::Persona.order(:id).first : nil]
        samples << ["Journey", defined?(::Journey) ? ::Journey.order(:id).first : nil]
        samples.each do |label, rec|
          if rec.nil?
            io.puts "#{label}: (none — seed fixtures first)"
          else
            proj = self.for(rec)
            io.puts "#{label}##{rec.id} => #{proj['cid']} type=#{proj['@type']} digest=#{proj['digest']}"
          end
        end
        samples
      end

      def intrinsic_payload(record)
        case record.class.name
        when "Mission"
          { "title" => record.title, "body" => record.body, "status" => record.status }
        when "Vision"
          { "title" => record.title, "body" => record.body, "status" => record.status,
            "time_horizon" => record.try(:time_horizon) }
        when "Persona"
          { "name" => record.name, "summary" => record.summary, "status" => record.status,
            "persona_role" => record.persona_role }
        when "Actor"
          { "name" => record.name, "role_key" => record.role_key }
        when "Journey"
          { "title" => record.title, "goal" => record.goal, "scenario" => record.scenario,
            "status" => record.status, "primary_actor_id" => record.primary_actor_id }
        when "Flow"
          { "title" => record.title, "task_goal" => record.task_goal, "status" => record.status,
            "journey_id" => record.journey_id }
        else
          record.attributes.except("updated_at")
        end
      end
      private_class_method :intrinsic_payload

      def default_placement(record)
        placed = record.try(:ledger_placement).to_s
        return placed if %w[canonical sync_intent private_local].include?(placed)
        case record.try(:status).to_s
        when "draft" then "sync_intent"
        else "canonical"
        end
      end
      private_class_method :default_placement

      def canonical_json(obj)
        JSON.generate(deep_sort(obj))
      end
      private_class_method :canonical_json

      def deep_sort(obj)
        case obj
        when Hash
          obj.keys.map(&:to_s).sort.each_with_object({}) { |k, h| h[k] = deep_sort(obj[k] || obj[k.to_sym]) }
        when Array then obj.map { |v| deep_sort(v) }
        else obj
        end
      end
      private_class_method :deep_sort
    end
  end
end
