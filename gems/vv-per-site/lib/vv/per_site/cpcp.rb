# frozen_string_literal: true

module Vv
  module PerSite
    # The per-site guide at the CPCP seam, so an agent walks the same
    # questions an anonymous visitor walks -- one projection, two callers.
    #
    # Reads are pulls; registering a site or binding a CTA is a push, so the
    # dispatcher requires an operationId and replays the receipt on retry.
    # Never raises: every path returns { ok:, ... } or
    # { ok: false, reason:, because: }.
    #
    # Call from an initializer (the engine does this after_initialize).
    # Skipped silently when rails-cpcp is absent, so the gem stays usable
    # outside a Rails app.
    module Cpcp
      module_function

      OPERATIONS = %w[
        persite.guide.root
        persite.guide.at
        persite.guide.choose
        persite.sites.list
        persite.leaves.list
        persite.site.register
        persite.cta.register
        persite.cta.remove
      ].freeze

      def register!
        # The guard is .project, not the module. Bundler evaluates every path
        # gemspec at setup, and each gemspec requires its version file -- so in
        # any process booted from the root bundle `::RailsCpcp` is already
        # defined with ONLY VERSION, rails-cpcp itself never required. A
        # defined?-only guard walks into NoMethodError there instead of
        # refusing (mmg-blob's absent-test fails exactly this way under the
        # root bundle).
        unless defined?(::RailsCpcp) && ::RailsCpcp.respond_to?(:project)
          return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" }
        end

        ::RailsCpcp.project(model: "PerSite") do
          operation "persite.guide.root", direction: :pull, params: %w[site_key],
            summary: "First question for this site: root node, its answer-options, and its CTA (nil unless the root is a bound leaf)",
            via: ->(p, _ctx) { Cpcp.guide_root(p) }

          operation "persite.guide.at", direction: :pull, params: %w[site_key okf_path],
            summary: "The guide step at an OKF path: node, its answer-options, and this site's CTA (nil unless bound)",
            via: ->(p, _ctx) { Cpcp.guide_at(p) }

          operation "persite.guide.choose", direction: :pull, params: %w[site_key from_path child_path],
            summary: "Answer the question at from_path with one of its options; refuses not_a_child otherwise",
            via: ->(p, _ctx) { Cpcp.guide_choose(p) }

          # Returns { ok:, sites: [...] }, an OBJECT. Not result: :collection:
          # an operation is a collection when what it returns IS the list, not
          # when it contains one (mmg-blob learned this on blob.entries).
          operation "persite.sites.list", direction: :pull,
            summary: "Every site in the market: key, name, host, bundle_key, cta_count",
            via: ->(_p, _ctx) { Cpcp.sites_list }

          operation "persite.leaves.list", direction: :pull, params: %w[bundle_key],
            summary: "Every CTA leaf in a bundle. Optional site_key adds this site's binding (cta:) or nil beside each leaf",
            via: ->(p, _ctx) { Cpcp.leaves_list(p) }

          operation "persite.site.register", direction: :push, params: %w[operationId key name bundle_key],
            summary: "Create the site, or re-point it (name, host, bundle_key) when the key exists",
            via: ->(p, _ctx) { Cpcp.site_register(p) }

          operation "persite.cta.register", direction: :push,
            params: %w[operationId site_key okf_path key title action_kind],
            summary: "Bind this site's action onto a CTA leaf (calendar, form, download, url, message, custom). Optional payload object",
            via: ->(p, _ctx) { Cpcp.cta_register(p) }

          operation "persite.cta.remove", direction: :push, params: %w[operationId site_key okf_path],
            summary: "Unbind this site's CTA from a leaf; refuses no_binding when there is nothing there",
            via: ->(p, _ctx) { Cpcp.cta_remove(p) }
        end

        { ok: true, operations: OPERATIONS }
      end

      def guide_root(params)
        with_guide(params) { |guide| serialize_step(guide.root) }
      end

      def guide_at(params)
        path = param(params, "okf_path")
        return refuse(:path_required, "persite.guide.at needs okf_path") if path.empty?

        with_guide(params) { |guide| serialize_step(guide.at(path)) }
      end

      def guide_choose(params)
        from = param(params, "from_path")
        child = param(params, "child_path")
        return refuse(:path_required, "persite.guide.choose needs from_path and child_path") if from.empty? || child.empty?

        with_guide(params) { |guide| serialize_step(guide.choose(from, child)) }
      end

      def sites_list
        guard do
          sites = Site.order(:key).map { |s| serialize_site(s) }
          { ok: true, sites: sites }
        end
      end

      def leaves_list(params)
        bundle = param(params, "bundle_key")
        return refuse(:bundle_required, "persite.leaves.list needs bundle_key") if bundle.empty?

        guard do
          site = nil
          raw_key = param(params, "site_key")
          unless raw_key.empty?
            site = Site.find_by(key: raw_key)
            return refuse(:unknown_site, "no site with key #{raw_key.inspect}") if site.nil?
          end

          leaves = OkfNode.in_bundle(bundle).cta_leaves.order(:okf_path).map do |leaf|
            entry = serialize_node(leaf)
            entry[:cta] = site.nil? ? nil : serialize_cta(site.ctas.find_by(okf_node_id: leaf.id))
            entry
          end
          { ok: true, bundle_key: bundle, leaves: leaves }
        end
      end

      def site_register(params)
        key = param(params, "key")
        return refuse(:key_required, "persite.site.register needs key") if key.empty?

        guard do
          site = Site.find_or_initialize_by(key: key)
          created = site.new_record?
          site.name = param(params, "name")
          site.bundle_key = param(params, "bundle_key")
          site.host = param(params, "host") unless param(params, "host").empty?
          return refuse(:site_invalid, site.errors.full_messages.join("; ")) unless site.save

          { ok: true, created: created, site: serialize_site(site) }
        end
      end

      def cta_register(params)
        payload = params["payload"].nil? ? params[:payload] : params["payload"]
        unless payload.nil? || payload.is_a?(Hash)
          return refuse(:payload_invalid, "payload must be an object, not #{payload.class}")
        end

        with_site(params) do |site|
          path = param(params, "okf_path")
          return refuse(:path_required, "persite.cta.register needs okf_path") if path.empty?

          leaf = site.bundle_nodes.find_by(okf_path: path)
          return refuse(:unknown_path, "#{path.inspect} is not in bundle #{site.bundle_key.inspect}") if leaf.nil?
          return refuse(:not_a_cta_leaf, "#{path.inspect} is a #{leaf.kind}, not a CTA leaf") unless leaf.cta_leaf?

          cta = site.ctas.find_or_initialize_by(okf_node_id: leaf.id)
          cta.key = param(params, "key")
          cta.title = param(params, "title")
          cta.action_kind = param(params, "action_kind")
          cta.payload = payload || {}
          return refuse(:cta_invalid, cta.errors.full_messages.join("; ")) unless cta.save

          { ok: true, cta: serialize_cta(cta) }
        end
      end

      def cta_remove(params)
        with_site(params) do |site|
          path = param(params, "okf_path")
          return refuse(:path_required, "persite.cta.remove needs okf_path") if path.empty?

          leaf = site.bundle_nodes.find_by(okf_path: path)
          return refuse(:unknown_path, "#{path.inspect} is not in bundle #{site.bundle_key.inspect}") if leaf.nil?

          cta = site.ctas.find_by(okf_node_id: leaf.id)
          return refuse(:no_binding, "site #{site.key.inspect} has no CTA on #{path.inspect}") if cta.nil?

          key = cta.key
          cta.destroy!
          { ok: true, removed: key, okf_path: path }
        end
      end

      def serialize_site(site)
        { key: site.key, name: site.name, host: site.host,
          bundle_key: site.bundle_key, cta_count: site.ctas.count }
      end

      def serialize_node(node)
        { okf_path: node.okf_path, kind: node.kind, title: node.title,
          description: node.description, slug: node.slug, doc_type: node.doc_type,
          status: node.status, cta_leaf: node.cta_leaf?, tags: node.tags,
          sources: node.sources, frontmatter: node.frontmatter, body: node.body }
      end

      def serialize_cta(cta)
        return nil if cta.nil?

        { key: cta.key, title: cta.title, action_kind: cta.action_kind,
          payload: cta.payload, okf_path: cta.okf_node.okf_path, site_key: cta.site.key }
      end

      def serialize_step(step)
        return step unless step[:ok]

        { ok: true, node: serialize_node(step[:node]),
          options: step[:options], cta: serialize_cta(step[:cta]) }
      end

      def refuse(reason, because) = { ok: false, reason: reason, because: because }

      # Params arrive with string keys over the wire; accept symbols too, the
      # way mmg-blob does, so direct Ruby callers are not second-class.
      def param(params, name)
        (params[name].nil? ? params[name.to_sym] : params[name]).to_s
      end

      def with_site(params)
        key = param(params, "site_key")
        return refuse(:site_required, "a site_key is required") if key.empty?

        guard do
          site = Site.find_by(key: key)
          return refuse(:unknown_site, "no site with key #{key.inspect}") if site.nil?

          yield site
        end
      end

      def with_guide(params)
        with_site(params) { |site| yield site.guide }
      end

      def guard
        yield
      rescue StandardError => e
        refuse(:store_error, "#{e.class}: #{e.message}")
      end
    end
  end
end
