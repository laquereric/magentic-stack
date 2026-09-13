# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module CucumberWorld
      attr_accessor :probe, :started, :last_snapshot, :board_url, :fixture_path

      def procedures
        ::Vv::Browser::Procedures
      end

      def board_url!
        self.board_url ||= ENV.fetch("BOARD_URL", "http://127.0.0.1:14001/")
      end

      def engine_name
        (ENV["ENGINE"] || "chrome").to_sym
      end

      def open_probe!(url)
        close_probe!
        started = ::Vv::Browser.start_session(engine: engine_name, headless: true)
        raise "start_session failed: #{started.inspect}" unless started[:ok]

        self.started = started
        self.probe = started[:probe]
        probe.observe!
        nav = probe.navigate(url)
        raise "navigate failed: #{nav.inspect}" unless nav[:ok]

        probe.wait(1.0)
        probe
      end

      def close_probe!
        probe&.close
      ensure
        self.probe = nil
        self.started = nil
      end

      def snapshot!
        raise "no probe" unless probe

        self.last_snapshot = probe.snapshot
      end
    end
  end
end
