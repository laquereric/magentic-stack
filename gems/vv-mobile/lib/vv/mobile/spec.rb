# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "yaml"

module Vv
  module Mobile
    # Parsed, validated domain spec that all three Swift emitters consume.
    # Types in the spec are Swift types (String, Int, Bool, Double, Date, [T], T?).
    class Spec
      IDENT = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      attr_reader :module_name, :base_url, :models, :repositories

      def self.parse(input)
        hash = case input
               when self then return { ok: true, spec: input }
               when Hash then stringify(input)
               when String
                 path_or_yaml = input
                 raw = File.file?(path_or_yaml) ? File.read(path_or_yaml) : path_or_yaml
                 loaded = YAML.safe_load(raw, permitted_classes: [], aliases: false)
                 return fail_env("invalid_spec", "YAML did not produce a mapping") unless loaded.is_a?(Hash)
                 stringify(loaded)
               else
                 return fail_env("invalid_spec", "spec must be a Hash, YAML string, file path, or Spec")
               end
        spec = new(hash)
        check = spec.validate
        return check unless check[:ok]

        { ok: true, spec: spec }
      rescue Psych::SyntaxError => e
        fail_env("invalid_spec", "YAML syntax: #{e.message}")
      end

      def initialize(hash)
        @module_name = hash["module"] || hash["module_name"] || "SharedKit"
        @base_url = hash["base_url"] || "https://api.example.com"
        @models = Array(hash["models"]).map { |m| self.class.stringify(m) }
        @repositories = Array(hash["repositories"]).map { |r| self.class.stringify(r) }
      end

      def validate
        return fail_env("invalid_spec", "module must be a Swift identifier") unless @module_name.is_a?(String) && @module_name.match?(IDENT)
        return fail_env("invalid_spec", "base_url must be a String") unless @base_url.is_a?(String) && !@base_url.strip.empty?

        model_names = []
        @models.each_with_index do |model, i|
          name = model["name"]
          return fail_env("invalid_spec", "models[#{i}].name must be a Swift identifier") unless name.is_a?(String) && name.match?(IDENT)
          model_names << name
          props = Array(model["properties"])
          return fail_env("invalid_spec", "models[#{name}] needs at least one property") if props.empty?
          props.each_with_index do |prop, j|
            p = self.class.stringify(prop)
            unless p["name"].is_a?(String) && p["name"].match?(IDENT)
              return fail_env("invalid_spec", "models[#{name}].properties[#{j}].name must be a Swift identifier")
            end
            unless p["type"].is_a?(String) && !p["type"].strip.empty?
              return fail_env("invalid_spec", "models[#{name}].properties[#{j}].type is required")
            end
          end
        end

        @repositories.each_with_index do |repo, i|
          name = repo["name"]
          return fail_env("invalid_spec", "repositories[#{i}].name must be a Swift identifier") unless name.is_a?(String) && name.match?(IDENT)
          model = repo["model"]
          return fail_env("invalid_spec", "repositories[#{name}].model is required") unless model.is_a?(String)
          unless model_names.include?(model)
            return fail_env("invalid_spec", "repositories[#{name}].model #{model.inspect} is not in models")
          end
        end

        { ok: true }
      end

      def model(name)
        @models.find { |m| m["name"] == name }
      end

      def properties_for(model)
        Array(model["properties"]).map { |p| self.class.stringify(p) }
      end

      def self.stringify(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array
          obj.map { |v| stringify(v) }
        else
          obj
        end
      end

      def self.fail_env(reason, because)
        { ok: false, reason: reason, because: because }
      end
      private_class_method :fail_env

      def fail_env(reason, because)
        self.class.send(:fail_env, reason, because)
      end
      private :fail_env
    end
  end
end
