# frozen_string_literal: true

require "fileutils"

module Vv
  module Figma
    # Install the plugin load into an overlay `public/`.
    # magentic-stack FRONT copies this the same way vv-miro copies its
    # browser load — it does not reimplement Figma calls in editor.js.
    module Assets
      ROOT = File.expand_path("../../../public", __dir__)

      module_function

      def js = File.join(ROOT, "vv-figma.js")

      def index_html = File.join(ROOT, "index.html")

      def code_js = File.join(ROOT, "code.js")

      def manifest = File.join(ROOT, "manifest.json")

      def install!(public_path)
        dest = public_path.to_s
        return Envelope.refuse(:dest_required, "Assets.install! needs a destination path") if dest.empty?

        FileUtils.mkdir_p(dest)
        copied = []
        {
          "vv-figma.js" => js,
          "vv-figma.html" => index_html,
          "vv-figma-code.js" => code_js,
          "vv-figma-manifest.json" => manifest
        }.each do |name, src|
          next unless File.file?(src)

          FileUtils.cp(src, File.join(dest, name))
          copied << name
        end
        Envelope.ok(data: { dest: dest, copied: copied })
      end
    end
  end
end
