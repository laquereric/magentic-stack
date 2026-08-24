# frozen_string_literal: true

require "pathname"

module Vv
  module Html
    module Components
      # Optional server-framework helper. Not required to serve or run the
      # browser library. The browser loads dist/vv-html-components.js directly.
      module AssetPath
        module_function

        def gem_root
          Pathname(__dir__).join("../../../..").expand_path
        end

        def js
          gem_root.join("dist", "vv-html-components.js")
        end

        def include_tag
          %(<script src="/assets/vv-html-components/vv-html-components.js" defer></script>)
        end
      end
    end
  end
end
