# frozen_string_literal: true

module Vv
  module Frame
    # The bundle's own gate. Each check is falsifiable: break the bundle in the
    # way the check names, and the check fails.
    #
    # The symmetry check is the load-bearing one. A decision that links to a
    # frame section the section does not list back is a claim with no reverse
    # entry -- exactly the shape of a contract maintained beside the code.
    module Validator
      module_function

      def call(bundle)
        errors = []
        errors.concat(dangling_links(bundle))
        errors.concat(asymmetric_links(bundle))
        errors.concat(orphans(bundle))
        errors.concat(unknown_placements(bundle))
        { ok: errors.empty?, errors: errors, edges: edges(bundle).size }
      end

      # adr -> frame#slug, as declared in each decision's Frame section.
      def edges(bundle)
        bundle.decisions.flat_map do |d|
          d.grounds.map { |g| { adr_id: d.id, slug: g[:slug], file: File.basename(d.okf_path) } }
        end
      end

      def dangling_links(bundle)
        slugs = bundle.sections.map(&:slug)
        ids = bundle.decisions.map(&:id)
        out = []
        edges(bundle).each do |e|
          out << err(:dangling_anchor, "adr #{e[:adr_id]} -> frame##{e[:slug]}") unless slugs.include?(e[:slug])
        end
        bundle.sections.each do |s|
          s.grounded_by.each do |g|
            out << err(:dangling_decision, "frame##{s.slug} -> adr #{g[:id]}") unless ids.include?(g[:id])
          end
        end
        out
      end

      def asymmetric_links(bundle)
        out = []
        edges(bundle).each do |e|
          section = bundle.section(e[:slug])
          next if section.nil?

          listed = section.grounded_by.any? { |g| g[:id] == e[:adr_id] }
          next if listed

          out << err(:asymmetric, "adr #{e[:adr_id]} -> frame##{e[:slug]}, not listed back")
        end
        bundle.sections.each do |s|
          s.grounded_by.each do |g|
            d = bundle.decisions.find { |x| x.id == g[:id] }
            next if d.nil? || d.grounds.any? { |x| x[:slug] == s.slug }

            out << err(:asymmetric, "frame##{s.slug} -> adr #{g[:id]}, not linked back")
          end
        end
        out
      end

      # A decision nothing reaches is not wrong, but it is invisible, and an
      # invisible constraint is one nobody will read before breaking it.
      def orphans(bundle)
        bundle.decisions.reject { |d| d.grounds.any? }
              .map { |d| err(:orphan, "adr #{d.id} grounds no frame section") }
      end

      def unknown_placements(bundle)
        bundle.decisions.reject { |d| d.placement.known? }
              .map { |d| err(:unknown_placement, "adr #{d.id}: #{d.placement.to_h}") }
      end

      def err(reason, because) = { reason: reason, because: because }
    end
  end
end
