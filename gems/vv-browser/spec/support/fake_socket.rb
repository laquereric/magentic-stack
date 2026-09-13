# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module SpecSupport
  # In-memory socket for BiDi transport tests (design §6, §8).
  class FakeSocket
    attr_reader :written, :url

    def initialize(peer: nil)
      @peer = peer
      @written = []
      @inbound = []
      @open = false
      @url = nil
    end

    def peer=(p)
      @peer = p
    end

    def connect(url, headers: {})
      @url = url.to_s
      @open = true
      { ok: true, url: @url }
    end

    def write(text)
      @written << text.to_s
      @peer&.on_client_write(text.to_s) if @peer
      true
    end

    def push(frame)
      @inbound << frame
    end

    def read_available
      batch = @inbound.dup
      @inbound.clear
      batch
    end

    def close
      @open = false
      true
    end

    def open?
      @open
    end
  end
end
