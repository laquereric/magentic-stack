# frozen_string_literal: true

require "securerandom"

module Vv
  module UseCase
    # Derive sharedai.uc.essentials.v1 from Fabric JSON. Drawing is truth.
    # Unknown objects (poster shapes) are ignored. Never writes IRIs.
    module Model
      KINDS = %w[system actor usecase association].freeze
      ROLES = %w[primary supporting].freeze
      STEREOTYPES = [nil, "", "include", "extend"].freeze

      module_function

      def extract(fabric, title: nil, digest: nil)
        canvas = stringify(fabric)
        objects = Array(canvas["objects"])
        system = nil
        actors = []
        use_cases = []
        associations = []

        objects.each do |raw|
          obj = stringify(raw)
          kind = obj["ucKind"].to_s
          next unless KINDS.include?(kind)

          case kind
          when "system"
            system = geom(obj).merge(
              "id" => id_for(obj, "sys"),
              "label" => label_of(obj, "System of interest")
            )
          when "actor"
            role = obj["ucRole"].to_s
            role = "primary" unless ROLES.include?(role)
            actors << geom(obj).merge(
              "id" => id_for(obj, "act"),
              "label" => label_of(obj, "Actor"),
              "role" => role
            )
          when "usecase"
            use_cases << geom(obj).merge(
              "id" => id_for(obj, "uc"),
              "label" => label_of(obj, "Use case")
            )
          when "association"
            associations << {
              "id" => id_for(obj, "as"),
              "from" => obj["ucFrom"].to_s,
              "to" => obj["ucTo"].to_s,
              "stereotype" => stereotype_of(obj)
            }
          end
        end

        if actors.empty? && use_cases.empty?
          return overlay_refuse("empty_use_case", "a use-case diagram needs an actor or a use case")
        end

        model = {
          "ok" => true,
          "schema" => SCHEMA,
          "title" => title.to_s.empty? ? "Untitled" : title.to_s,
          "digest" => digest.to_s,
          "width" => num(canvas["width"], 900),
          "height" => num(canvas["height"], 1200),
          "system" => system,
          "actors" => actors,
          "use_cases" => use_cases,
          "associations" => associations
        }
        model
      end

      def geom(obj)
        w = num(obj["width"], num(obj["rx"], 40) * 2)
        h = num(obj["height"], num(obj["ry"], 24) * 2)
        {
          "x" => num(obj["left"], 0),
          "y" => num(obj["top"], 0),
          "w" => w,
          "h" => h
        }
      end

      def label_of(obj, fallback)
        text = obj["text"].to_s
        return text unless text.empty?

        Array(obj["objects"]).each do |child|
          t = stringify(child)["text"].to_s
          return t unless t.empty?
        end
        fallback
      end

      def id_for(obj, prefix)
        id = obj["ucId"].to_s
        return id unless id.empty?

        name = obj["name"].to_s
        return name unless name.empty?

        "#{prefix}_#{SecureRandom.hex(3)}"
      end

      def stereotype_of(obj)
        s = obj["ucStereotype"]
        return nil if s.nil? || s.to_s.empty?
        return s.to_s if %w[include extend].include?(s.to_s)

        nil
      end

      def num(value, default)
        f = Float(value)
        f.nan? ? default : f
      rescue ArgumentError, TypeError
        default
      end

      def stringify(value)
        case value
        when Hash
          value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
        when Array
          value.map { |v| stringify(v) }
        else
          value
        end
      end

      def overlay_refuse(reason, because)
        { "ok" => false, "reason" => reason.to_s, "because" => because.to_s }
      end
    end
  end
end
