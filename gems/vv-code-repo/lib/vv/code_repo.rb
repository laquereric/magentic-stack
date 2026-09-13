# frozen_string_literal: true

require_relative "code_repo/version"
require_relative "code_repo/refusal"
require_relative "code_repo/grant"
require_relative "code_repo/operations"
require_relative "code_repo/catalog"
require_relative "code_repo/store"
require_relative "code_repo/cpcp"
require_relative "code_repo/engine" if defined?(::Rails::Railtie)

module Vv
  # Procedure catalog contract: digest-named revisions on BACK AR + blob.
  # Plan: docs/architecture/plan_procedure_repo.md
  #
  # CONTRACT ONLY. No AR models, no columnar engine, no eval of procedures.
  module CodeRepo
    module_function

    def frame
      "BACK catalog of procedures: digest is the name, Gold is what PROD reads, " \
        "HTML is a projection, Platinum is not a tier"
    end
  end
end
