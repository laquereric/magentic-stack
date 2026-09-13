# frozen_string_literal: true

require "fileutils"

module Vv
  module Canvas
    module Assets
      ROOT = File.expand_path("../../../public", __dir__)

      module_function

      def editor_js = File.join(ROOT, "editor.js")

      def editor_css = File.join(ROOT, "editor.css")

      def fabric_dir = File.join(ROOT, "vendor", "fabric-7.4.0")

      def install!(public_path)
        dest = public_path.to_s
        FileUtils.mkdir_p(dest)
        FileUtils.cp(editor_js, File.join(dest, "editor.js")) if File.file?(editor_js)
        FileUtils.cp(editor_css, File.join(dest, "editor.css")) if File.file?(editor_css)
        if File.directory?(fabric_dir)
          FileUtils.mkdir_p(File.join(dest, "vendor"))
          FileUtils.cp_r(fabric_dir, File.join(dest, "vendor", "fabric-7.4.0"))
        end
        { ok: true, dest: dest }
      end
    end
  end
end
