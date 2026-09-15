# frozen_string_literal: true

require "fileutils"

module Vv
  module Miro
    # Install the single browser load into an overlay `public/`.
    # magentic-stack FRONT copies this the same way vv-canvas copies
    # Fabric — it does not reimplement Miro calls in editor.js.
    module Assets
      ROOT = File.expand_path("../../../public", __dir__)

      module_function

      def js = File.join(ROOT, "vv-miro.js")

      def index_html = File.join(ROOT, "index.html")

      def install!(public_path)
        dest = public_path.to_s
        return Envelope.refuse(:dest_required, "Assets.install! needs a destination path") if dest.empty?

        FileUtils.mkdir_p(dest)
        copied = []
        if File.file?(js)
          FileUtils.cp(js, File.join(dest, "vv-miro.js"))
          copied << "vv-miro.js"
        end
        if File.file?(index_html)
          FileUtils.cp(index_html, File.join(dest, "vv-miro.html"))
          copied << "vv-miro.html"
        end
        Envelope.ok(data: { dest: dest, copied: copied })
      end
    end
  end
end
