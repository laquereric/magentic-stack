# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "../../spec_helper"

RSpec.describe Vv::Browser::Procedures do
  describe ".flatten_console" do
    it "extracts level, text, args, and stack frames" do
      entry = described_class.flatten_console(
        "level" => "error",
        "type" => "javascript",
        "text" => "Cannot set property type of [object Object] which has only a getter",
        "args" => [{ "value" => "extra" }],
        "stackTrace" => {
          "callFrames" => [
            # The URL is a BROWSER stack frame -- the page's path, not this
            # repo's. It is written as an absolute example.invalid URL because
            # check_closed reads source without knowing which strings are
            # fixtures, and the old relative prefix here names a directory this
            # repo removed. A rule that trusted "it is only a test" would be a
            # rule with a hole in it. The assertion is about level and type.
            { "functionName" => "e._set",
              "url" => "https://example.invalid/fabric-7.4.0/index.min.js",
              "lineNumber" => 1, "columnNumber" => 2 }
          ]
        }
      )
      expect(entry[:level]).to eq("error")
      expect(entry[:type]).to eq("javascript")
      expect(entry[:text]).to include("only a getter")
      expect(entry[:args]).to include("extra")
      expect(entry[:stack]).to include("e._set")
      expect(entry[:stack]).to include("fabric-7.4.0")
    end

    it "joins args when text is empty" do
      entry = described_class.flatten_console("level" => "error", "args" => [{ "value" => "boom" }])
      expect(entry[:text]).to eq("boom")
    end
  end

  describe ".flatten_network" do
    it "extracts url, status, method" do
      n = described_class.flatten_network(
        "request" => { "method" => "POST", "url" => "http://127.0.0.1:14001/canvas/blob" },
        "response" => { "url" => "http://127.0.0.1:14001/canvas/blob", "status" => 502 }
      )
      expect(n[:url]).to include("/canvas/blob")
      expect(n[:status]).to eq(502)
      expect(n[:method]).to eq("POST")
    end
  end

  describe ".javascript_errors / .getter_errors" do
    let(:entries) do
      [
        { level: "info", type: "console", text: "ok" },
        { level: "error", type: "javascript", text: "TypeError: Cannot set property type of [object Object] which has only a getter", stack: "e._set @ fabric" },
        { level: "error", type: "javascript", text: "Uncaught boom" }
      ]
    end

    it "selects error-level and TypeError text" do
      errs = described_class.javascript_errors(entries)
      expect(errs.map { |e| e[:text] }).to include("Uncaught boom")
      expect(errs.length).to eq(2)
    end

    it "isolates Fabric type-getter failures" do
      hits = described_class.getter_errors(entries)
      expect(hits.length).to eq(1)
      expect(hits.first[:text]).to include("only a getter")
    end
  end

  describe ".digest? / .status_looks_like_digest?" do
    it "accepts sha256:<64 hex>" do
      d = "sha256:" + ("a" * 64)
      expect(described_class.digest?(d)).to eq(true)
      expect(described_class.status_looks_like_digest?(d)).to eq(true)
      expect(described_class.status_looks_like_digest?("#{d} (hot cache)")).to eq(true)
    end

    it "rejects missing_params status" do
      expect(described_class.status_looks_like_digest?("blob.put refused: missing_params")).to eq(false)
      expect(described_class.digest?("cid:acia:abc")).to eq(false)
    end
  end

  describe ".click_id_js / .click_button_text_js" do
    it "embeds the element id" do
      js = described_class.click_id_js("addHeading")
      expect(js).to include("addHeading")
      expect(js).to include("getElementById")
      expect(js).to include(".click()")
    end

    it "embeds the button label and optional root" do
      js = described_class.click_button_text_js("Poster", within: "#templateGrid")
      expect(js).to include("Poster")
      expect(js).to include("#templateGrid")
      expect(js).to include(".click()")
    end
  end

  describe ".board_snapshot_js" do
    it "reads saveStatus, layerList, fabric, templates" do
      js = described_class.board_snapshot_js
      expect(js).to include("saveStatus")
      expect(js).to include("layerList")
      expect(js).to include("templateGrid")
      expect(js).to include("window.fabric")
    end
  end

  describe ".throw_fixture_html" do
    it "emits a page that console.errors and throws" do
      html = described_class.throw_fixture_html("boom")
      expect(html).to include("throw-fixture")
      expect(html).to include("console.error")
      expect(html).to include("boom")
    end
  end

  describe ".console_entries / .network_entries" do
    it "filters mixed BiDi event hashes" do
      events = [
        { method: "log.entryAdded", params: { "level" => "error", "text" => "x" } },
        { method: "network.responseCompleted", params: { "response" => { "url" => "http://x/y", "status" => 200 }, "request" => { "method" => "GET" } } },
        { method: "browsingContext.load", params: {} }
      ]
      cons = described_class.console_entries(events)
      net = described_class.network_entries(events)
      expect(cons.map { |e| e[:text] }).to eq(["x"])
      expect(net.map { |e| e[:status] }).to eq([200])
    end

    it "accepts EventEnvelope objects" do
      ev = Vv::Browser::Protocol::EventEnvelope.new(
        method: "log.entryAdded",
        params: { "level" => "info", "text" => "hello console" }
      )
      expect(described_class.console_entries([ev]).first[:text]).to eq("hello console")
    end
  end

  describe ".http_failures" do
    it "keeps 4xx/5xx" do
      net = [
        { url: "/ok", status: 200 },
        { url: "/canvas/blob", status: 502 }
      ]
      expect(described_class.http_failures(net).map { |n| n[:status] }).to eq([502])
    end
  end

  describe ".reachable?" do
    it "is false for a closed port" do
      expect(described_class.reachable?("http://127.0.0.1:1/", timeout: 0.2)).to eq(false)
    end
  end
end
