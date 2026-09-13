# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

ENV["LANG"] ||= "en_US.UTF-8"
ENV["LC_ALL"] ||= "en_US.UTF-8"

require_relative "../../spec_helper"
require_relative "../../support/fake_socket"
require_relative "../../support/scripted_bidi_peer"

RSpec.describe "vv-browser BiDi core" do
  def mock_transport
    sock = SpecSupport::FakeSocket.new
    peer = SpecSupport::ScriptedBidiPeer.new(sock)
    peer.emit_event("log.entryAdded", { "text" => "hello console", "level" => "info" })
    transport = Vv::Browser::Transport::WebSocket.new(socket: sock)
    [transport, sock, peer]
  end

  before do
    Vv::Browser::GraphGrounding.clear!
    Vv::Browser.driver_registry.clear
    Vv::Browser.last_driver = nil
  end

  describe Vv::Browser::Protocol do
    it "parses command/response/event envelopes" do
      cmd = Vv::Browser::Protocol::CommandEnvelope.new(id: 1, method: "session.subscribe", params: { "events" => ["log.entryAdded"] })
      expect(cmd.to_h["method"]).to eq("session.subscribe")

      resp = Vv::Browser::Protocol::ResponseEnvelope.parse({ "id" => 1, "result" => {} })
      expect(resp.ok?).to eq(true)

      err = Vv::Browser::Protocol::ResponseEnvelope.parse({ "id" => 2, "error" => "unknown error", "message" => "boom" })
      expect(err.ok?).to eq(false)

      ev = Vv::Browser::Protocol::EventEnvelope.parse({ "method" => "log.entryAdded", "params" => { "text" => "x" } })
      expect(ev.method).to eq("log.entryAdded")
    end
  end

  describe Vv::Browser::Transport::WebSocket do
    it "correlates command responses by id" do
      transport, = mock_transport
      transport.connect("ws://mock/session")
      r = transport.send_command("browsingContext.create", { "type" => "tab" }, timeout: 2)
      expect(r[:ok]).to eq(true)
      expect(r[:result]["context"]).to eq("ctx_mock_1")
    end

    it "buffers events and supports subscription handlers" do
      transport, sock, peer = mock_transport
      transport.connect("ws://mock/session")
      seen = []
      transport.on_event("log.entryAdded") { |e| seen << e.params["text"] }
      # peer queues event before next command; send_command drains
      r = transport.send_command("session.subscribe", { "events" => ["log.entryAdded"] }, timeout: 2)
      expect(r[:ok]).to eq(true)
      expect(seen).to include("hello console")
      expect(transport.events.map(&:method)).to include("log.entryAdded")
    end

    it "returns timeout when peer is silent" do
      sock = SpecSupport::FakeSocket.new
      # no peer — writes go nowhere
      transport = Vv::Browser::Transport::WebSocket.new(socket: sock)
      transport.connect("ws://mock/session")
      r = transport.send_command("session.subscribe", {}, timeout: 0.05)
      expect(r[:ok]).to eq(false)
      expect(r[:reason]).to eq(:timeout)
    end

    it "surfaces bidi errors" do
      sock = SpecSupport::FakeSocket.new
      peer = SpecSupport::ScriptedBidiPeer.new(sock)
      peer.on("script.evaluate") { |_p, _id| { "error" => "javascript error", "message" => "bad" } }
      transport = Vv::Browser::Transport::WebSocket.new(socket: sock)
      transport.connect("ws://mock/session")
      r = transport.send_command("script.evaluate", { "expression" => "throw 1" }, timeout: 2)
      expect(r[:ok]).to eq(false)
      expect(r[:reason]).to eq(:bidi_error)
    end
  end

  describe Vv::Browser::BiDiSession do
    it "opens from endpoint descriptor and exposes domain modules" do
      transport, = mock_transport
      session = described_class.new(transport: transport)
      opened = session.open(descriptor: { engine: :mock, ws_url: "ws://mock/session", bootstrap: :fresh })
      expect(opened[:ok]).to eq(true)

      sub = session.subscribe(["log.entryAdded", "network.responseCompleted"])
      expect(sub[:ok]).to eq(true)

      ctx = session.browsing_context.create
      expect(ctx[:ok]).to eq(true)
      expect(ctx[:context]).to eq("ctx_mock_1")

      nav = session.browsing_context.navigate(ctx[:context], "https://example.test/")
      expect(nav[:ok]).to eq(true)

      val = session.script.evaluate(ctx[:context], "document.title")
      expect(val[:ok]).to eq(true)
      expect(val[:value]).to eq("Mock Title")

      click = session.input.click(ctx[:context], x: 10, y: 20)
      expect(click[:ok]).to eq(true)

      net = session.network.add_intercept
      expect(net[:ok]).to eq(true)
      expect(net[:intercept]).to eq("ix_1")

      session.log.subscribe
      expect(session.log.texts).to include("hello console")

      shot = session.browsing_context.capture_screenshot(ctx[:context])
      expect(shot[:ok]).to eq(true)
    end
  end

  describe Vv::Browser::AgentDriver do
    it "drive affordance navigates/reads/acts/captures via mock" do
      transport, = mock_transport
      r = Vv::Browser.drive(url: "https://example.test/", engine: :mock, transport: transport) do |browser|
        read = browser.read
        expect(read[:ok]).to eq(true)
        expect(read[:title]).to eq("Mock Title")
        act = browser.act(kind: "evaluate", js: "1+1")
        expect(act[:ok]).to eq(true)
        cap = browser.capture
        expect(cap[:ok]).to eq(true)
        :done
      end
      expect(r[:ok]).to eq(true)
      expect(r[:result]).to eq(:done)
      expect(Vv::Browser::GraphGrounding.triples_log).not_to be_empty
    end
  end

  describe Vv::Browser::SalEventBridge do
    it "bridges bidi events with redaction" do
      bridge = described_class.new(intention: "t1")
      ev = Vv::Browser::Protocol::EventEnvelope.new(
        method: "network.beforeRequestSent",
        params: { "url" => "https://x.test", "password" => "secret", "headers" => { "Authorization" => "Bearer x" } }
      )
      r = bridge.bridge(ev)
      expect(r[:ok]).to eq(true)
      expect(r[:event]["params"]["password"]).to eq("[REDACTED]")
      expect(r[:event]["params"]["headers"]["Authorization"]).to eq("[REDACTED]")
    end
  end

  describe Vv::Browser::CapabilityMatrix do
    it "forbids session.new on chrome/chromium" do
      expect(described_class.supports?(:chrome, :session_new)).to eq(false)
      expect(described_class.supports?(:chromium, :session_new)).to eq(false)
      expect(described_class.supports?(:firefox, :session_new)).to eq(true)
    end
  end

  describe "MCB surface" do
    it "registers browser_open/navigate/read/act/capture/close" do
      names = Vv::Browser.mcb_actions.map { |a| a[:name] }
      expect(names).to include(
        "browser_open", "browser_navigate", "browser_read",
        "browser_act", "browser_capture", "browser_close"
      )
    end

    it "browser_open mock + navigate via registry" do
      transport, = mock_transport
      # open without auto-close via open_bidi
      opened = Vv::Browser.open_bidi(engine: :mock, transport: transport, url: "https://example.test/")
      expect(opened[:ok]).to eq(true)
      key = opened[:session_key]
      nav = Vv::Browser.mcb_actions.find { |a| a[:name] == "browser_navigate" }[:handler].call(
        { "url" => "https://example.test/2", "session_key" => key }, nil
      )
      expect(nav[:ok]).to eq(true)
      closed = Vv::Browser.mcb_actions.find { |a| a[:name] == "browser_close" }[:handler].call(
        { "session_key" => key }, nil
      )
      expect(closed[:ok]).to eq(true)
    end
  end
end
