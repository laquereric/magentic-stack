# frozen_string_literal: true

require "json"
require "pathname"

module RailsOsiLevel8
  # Resolve a stored shape_id ON READ. History is not rewritten (ADR 0060).
  # Mapping file is the single source: tooling/shacl/osi_example_successors.json.
  module ShapeId
    MAPPING_REL = "tooling/shacl/osi_example_successors.json"
    IMAGE_PATH = "/opt/magentic/osi_example_successors.json"

    module_function

    def mapping_path
      env = ENV["OSI_EXAMPLE_SUCCESSORS"].to_s
      return Pathname(env) unless env.empty?

      configured = RailsOsiLevel8.config.shape_id_successors_path
      return Pathname(configured) if configured.to_s.strip != ""

      image = Pathname(IMAGE_PATH)
      return image if image.file?

      Pathname(__dir__).expand_path.join("../../../../", MAPPING_REL)
    end

    def resolve(stored)
      iri = stored.to_s
      table = shapes
      if table.key?(iri)
        {
          "shape_id" => iri,
          "shape_id_resolved" => table[iri],
          "shape_id_resolution" => "historical"
        }
      elsif table.has_value?(iri)
        {
          "shape_id" => iri,
          "shape_id_resolved" => iri,
          "shape_id_resolution" => "current"
        }
      else
        {
          "shape_id" => iri,
          "shape_id_resolution" => "unresolved",
          "shape_id_unresolved" => {
            "ok" => false,
            "reason" => "shape_id_unresolved",
            "because" => "not in #{MAPPING_REL}"
          }
        }
      end
    end

    def shapes
      path = mapping_path
      return {} unless path.file?

      JSON.parse(File.read(path)).fetch("shapes")
    rescue StandardError
      {}
    end
  end
end
