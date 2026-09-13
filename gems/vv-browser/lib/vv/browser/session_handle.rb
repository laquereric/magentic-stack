# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    # SessionHandle — single source of truth for an engine-owned browser session.
    # Carries everything teardown needs (pid, HTTP port, session_id, profile_dir)
    # and everything the shared BiDi layer needs (bidi_url).
    class SessionHandle
      ATTRS = %i[
        engine bidi_url webdriver_url session_id capabilities
        profile_dir ephemeral_profile pid port driver_path
        session_new_sent bootstrap
      ].freeze
      attr_accessor(*ATTRS)

      def initialize(**h)
        ATTRS.each { |k| public_send("#{k}=", h[k] || h[k.to_s]) }
        @capabilities = (@capabilities || {}).transform_keys(&:to_s)
        @session_new_sent = !!@session_new_sent
        @ephemeral_profile = !!@ephemeral_profile
      end

      def to_h
        ATTRS.each_with_object({}) { |k, a| a[k] = public_send(k) }
      end
    end
  end
end
