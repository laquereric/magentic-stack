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

    # @return [String] the complete document
    def render(title:, stylesheet:, acia_json:, header:, body:, note: nil, hydrate: true)
      view.render(
        template: TEMPLATE,
        layout: LAYOUT,
        locals: { title: title, stylesheet: stylesheet, acia_json: acia_json,
                  header: header, note: note, hydrate: hydrate, body: body }
      )
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

          ::FileUtils.cp(src, ::File.join(dir, asset))
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
