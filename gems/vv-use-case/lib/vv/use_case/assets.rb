# frozen_string_literal: true

require "fileutils"

module Vv
  module UseCase
    # Install the Fabric plugin into an overlay public/. Do not fork
    # this file into overlay source.
    module Assets
      ROOT = File.expand_path("../../../public", __dir__)

      module_function

      def js = File.join(ROOT, "use-case.js")

      def install!(public_path)
        dest = public_path.to_s
        if dest.empty?
          return { "ok" => false, "reason" => "dest_required", "because" => "Assets.install! needs a destination path" }
        end

        FileUtils.mkdir_p(dest)
        copied = []
        if File.file?(js)
          FileUtils.cp(js, File.join(dest, "use-case.js"))
          copied << "use-case.js"
        end
        { "ok" => true, "dest" => dest, "copied" => copied }
      end
    end
  end
end
