# frozen_string_literal: true

module Vv
  module CodeRepo
    # DEV may write Gold. PROD may collect Bronze and serve Gold.
    # PROCEDURE_WRITE=1 is the v1 grant (plan open question 1).
    module Grant
      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def may_write_gold?(params = {})
        p = stringify(params)
        env = p["PROCEDURE_WRITE"] || p["procedure_write"] || ENV["PROCEDURE_WRITE"]
        env.to_s == "1"
      end

      def may_collect?(_params = {})
        true
      end

      def prod_write_gold?(params = {})
        !may_write_gold?(params)
      end
    end
  end
end
