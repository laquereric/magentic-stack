# frozen_string_literal: true

module Vv
  module DependencyOrch
    # WHEN a dependency matters. Four times, two stores.
    #
    # `.cpcp/package.json` already answers compile-time and runtime
    # format/protocol. Local and remote deploy are a different question: which
    # SHA must be at which placement for the overlay to run. Mixing them is how
    # a contract rev starts being treated as an image digest, and how a FLOOR
    # SHA starts being treated as a CID.
    #
    # This module is the vocabulary. It does not read either file.
    module When
      KINDS = {
        compile: "layout, language, contract rev -- .cpcp/package.json",
        runtime_protocol: "CID, operations, scopes, wire format -- .cpcp/package.json",
        local_deploy: "SHA of images and blobs that must be on this daemon / local blob store",
        remote_deploy: "SHA of images and blobs that must be on the registry / remote blob store"
      }.freeze

      PROTOCOL = %i[compile runtime_protocol].freeze
      DEPLOY = %i[local_deploy remote_deploy].freeze

      module_function

      def known?(value)
        KINDS.key?(value.to_sym)
      rescue StandardError
        false
      end

      def deploy?(value)
        DEPLOY.include?(value.to_sym)
      rescue StandardError
        false
      end

      def protocol?(value)
        PROTOCOL.include?(value.to_sym)
      rescue StandardError
        false
      end
    end
  end
end
