# frozen_string_literal: true

require "digest"

# ROLE=shape v1 retrieval catalog. Reads ProfileCatalog.default, groups
# by file digest. Does not call Shapes::Level8.catalog (that stub is
# empty). Does not move Grounding. POST rpc is not in v1.
class ShapeSurface
  RETRIEVAL_PREFIX = "/_cpcp/shapes/sha256:"

  # Re-measured 2026-09-02 on origin/main 185016f. Not the row-6
  # false reason ("shapes-level-8 is not in SHAPE_MAP") — L8_PROTOCOL_MAP
  # has 13 rows. Honest holes:
  INCOMPLETE_BECAUSE = [
    "P2-P8 and P10 protocol shapes are not in the pin",
    "Shapes::Level8.catalog is an empty stub; retrieval uses ProfileCatalog.default",
    "L8 bundles contextframe.shacl.ttl and profile-9-ghis.ttl are on disk and not in ProfileCatalog",
    "52 TTL remain in gems/osi-level-8-profiles (gap 23, not served)",
    "publication, trust metadata, compilation, compatibility evidence, and translation-profile metadata are unbuilt (ADR 0045)"
  ].freeze

  UNMIGRATED = 52

  # Empty catalog answering ok:true is the named failure mode.
  EMPTY = {
    "ok" => false,
    "reason" => "shape_catalog_empty",
    "because" => { "offender" => "ProfileCatalog.default" },
    "incomplete" => true,
    "incomplete_because" => INCOMPLETE_BECAUSE,
    "unmigrated" => UNMIGRATED,
    "shapes" => []
  }.freeze

  def self.document(catalog = RailsOsiLevel8::ProfileCatalog.default)
    new(catalog).document
  end

  def initialize(catalog = RailsOsiLevel8::ProfileCatalog.default)
    @catalog = catalog
  end

  def document
    grouped = public_files
    return EMPTY if grouped.empty?

    {
      "ok" => true,
      "incomplete" => true,
      "incomplete_because" => INCOMPLETE_BECAUSE,
      "unmigrated" => UNMIGRATED,
      "shapes" => grouped
    }
  end

  def files
    groups = {}
    Array(@catalog&.keys).each do |name|
      entry = @catalog.fetch(name)
      digest = entry.sha256.to_s
      gem_name, rel = gem_and_rel(entry.path)
      rec = groups[digest] ||= {
        "digest" => "sha256:#{digest}",
        "gem" => gem_name,
        "path" => rel,
        "rdf_iri" => [],
        "shape_names" => [],
        "retrieval" => "#{RETRIEVAL_PREFIX}#{digest}",
        "_path" => entry.path.to_s
      }
      rec["rdf_iri"] << entry.shape_iri unless rec["rdf_iri"].include?(entry.shape_iri)
      rec["shape_names"] << name unless rec["shape_names"].include?(name)
    end
    groups.values.sort_by { |r| r["digest"] }
  end

  def public_files
    files.map { |r| r.reject { |k, _| k.start_with?("_") } }
  end

  # Bytes of the TTL whose sha256 is hex. Digest mismatch or unknown
  # digest returns nil (HTTP 404, not a different graph).
  def turtle(hex)
    hex = hex.to_s.sub(/\Asha256:/, "")
    return nil unless hex.match?(/\A[0-9a-f]{64}\z/)

    rec = files.find { |r| r["digest"] == "sha256:#{hex}" }
    return nil if rec.nil?

    path = rec["_path"]
    return nil unless path && File.file?(path)

    bytes = File.binread(path)
    actual = Digest::SHA256.hexdigest(bytes)
    return nil unless actual == hex

    bytes
  end

  def artifacts
    files.map { |r| r["digest"] }
  end

  private

  # Gems ProfileCatalog may resolve from. Named here so retrieval does
  # not depend on ProfileCatalog::SHAPE_GEMS being a public constant.
  # rails-osi-level-8 is the pre-split home (image gem may still use
  # data/osi-level-8/*.ttl).
  FILE_GEMS = %w[shapes-application shapes-level-8 rails-osi-level-8].freeze

  def gem_and_rel(path)
    s = path.to_s
    FILE_GEMS.each do |gem_name|
      # Image gems are shapes-application-0.0.0/; repo fallback is
      # gems/shapes-application/.
      m = s.match(%r{/(#{Regexp.escape(gem_name)})(?:-[^/]+)?/(.+)\z})
      return [m[1], m[2]] if m
    end
    [nil, File.basename(s)]
  end
end
