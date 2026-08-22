# frozen_string_literal: true
require "action_view"
require "fileutils"

module AppOrientedTranslation
  # Renders a Profile 9 surface through the engine's SHARED layout.
  #
  # The point is that the static build scripts and a mounted engine render the
  # SAME FILE. A build script that reproduced the shell in a heredoc would drift
  # from the layout the moment either changed -- which is exactly what happened
  # before this existed, leaving the storyboards with no component runtime.
  #
  # This is presentation only. It never touches the ACIA document, so a page's
  # aciaDigest is unchanged by rendering it.
  module PageRenderer
    module_function

    VIEWS = ::File.expand_path("../../app/views", __dir__)
    LAYOUT = "layouts/app_oriented_translation/application"
    TEMPLATE = "app_oriented_translation/page"

    # The runtime + host Layout Projection a hydrated page needs beside it.
    # Same-directory relative srcs, so every surface copies them next to its HTML.
    ASSETS = %w[vv-html-components.js ux-host-layout.js].freeze

    # @param acia [Hash, nil] when supplied, the page layout is MATERIALIZED:
    #   AciaToHerb converts the top of the tree to static markup and the parts
    #   below the cut stay ACIA render references filled from `body`. When nil,
    #   the generated blob is emitted as-is (the JIT form).
    # @return [String] the complete document
    def render(title:, stylesheet:, acia_json:, header:, body:, note: nil, hydrate: true,
               acia: nil, cut: AciaToHerb::DEFAULT_CUT)
      locals = { title: title, stylesheet: stylesheet, acia_json: acia_json,
                 header: header, note: note, hydrate: hydrate, body: body }

      if acia
        m = materialize(acia: acia, body: body, cut: cut)
        # Fail closed. A half-materialized page would still look rendered, so a
        # refusal here is better than a page with a hole where a column was.
        raise ArgumentError, "cannot materialize layout: #{m[:reason]} -- #{m[:because]}" unless m[:ok]

        locals[:layout_erb] = m[:erb]
        locals[:slots] = m[:slots]
      end

      view.render(template: TEMPLATE, layout: LAYOUT, locals: locals)
    end

    # ACIA tree -> HERB -> (one-way) ERB, with every reference filled from the
    # renderer's OWN output. Nothing is re-rendered, so node cids and the
    # document digest are untouched by materializing.
    def materialize(acia:, body:, cut: AciaToHerb::DEFAULT_CUT)
      root_tag = RenderedSlots.render_root_tag(html: body.to_s)
      unless root_tag
        return { ok: false, reason: :no_render_root,
                 because: "the rendered body carries no .ux-render-root; a materialized layout outside it " \
                          "would never hydrate and would report no error" }
      end

      herb = AciaToHerb.convert(acia: acia, cut: cut, render_root: root_tag,
                                node_attrs: RenderedSlots.node_attrs(html: body.to_s))
      return herb unless herb[:ok]

      slots = RenderedSlots.extract(html: body.to_s, node_ids: herb[:slots].map { |s| s[:node_id] })
      return slots unless slots[:ok]

      erb = AciaToHerb.export_erb(herb: herb[:herb])
      return erb unless erb[:ok]

      { ok: true, erb: erb[:erb], herb: herb[:herb], slots: slots[:slots],
        materialized: herb[:materialized], referenced: herb[:referenced] }
    end

    # Write the document and, when it hydrates, place the runtime beside it.
    # A hydrating page whose assets are absent is a broken page, so the two
    # steps belong together rather than in each caller.
    def write(path:, assets_from: nil, **kw)
      dir = ::File.dirname(path)
      ::FileUtils.mkdir_p(dir)
      ::File.write(path, render(**kw))

      if kw.fetch(:hydrate, true) && assets_from
        ASSETS.each do |asset|
          src = assets_from.is_a?(Hash) ? assets_from[asset] : ::File.join(assets_from, asset)
          next if src.nil?

          raise ArgumentError, "missing runtime asset: #{src}" unless ::File.exist?(src)

          dest = ::File.join(dir, asset)
          # A surface may vendor from its own directory (a second page written
          # beside the first). Copying a file onto itself is not an error here.
          next if ::File.identical?(src, dest)

          ::FileUtils.cp(src, dest)
        end
      end
      path
    end

    def view
      lookup = ::ActionView::LookupContext.new([VIEWS])
      ::ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
    end
    private_class_method :view
  end
end
